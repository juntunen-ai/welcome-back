import Foundation
@preconcurrency import AVFoundation

// MARK: - Errors

enum LiveServiceError: LocalizedError {
    case apiKeyMissing
    case audioSetupFailed
    case connectionFailed
    case setupMessageFailed

    var errorDescription: String? {
        switch self {
        case .apiKeyMissing:       return "Gemini API key is not configured."
        case .audioSetupFailed:    return "Could not access the microphone."
        case .connectionFailed:    return "Could not connect to the live service."
        case .setupMessageFailed:  return "Session setup failed."
        }
    }
}

// MARK: - GeminiLiveService

/// Full-duplex voice session over the Gemini Multimodal Live WebSocket API.
///
/// Create a **new instance** per conversation session — do not reuse across sessions.
/// This ensures the AsyncStream, audio engine, and WebSocket are always fresh.
final class GeminiLiveService: @unchecked Sendable {

    // MARK: - State stream

    /// Subscribe once in `LiveSessionViewModel`. The stream finishes when
    /// `endSession()` is called, so the `for await` loop exits cleanly.
    let stateStream: AsyncStream<LiveSessionState>
    private let stateContinuation: AsyncStream<LiveSessionState>.Continuation

    private(set) var sessionState: LiveSessionState = .idle

    // MARK: - Private

    private let apiKey: String
    private var webSocketTask: URLSessionWebSocketTask?
    private var receiveLoopTask: Task<Void, Never>?

    // MARK: - Audio engine (one per instance)

    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var audioConfigured = false

    /// Capture format: 16 kHz, Int16, mono
    private let captureFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 16_000,
        channels: 1,
        interleaved: true
    )!

    /// Playback format: 24 kHz, Int16, mono
    private let playbackFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 24_000,
        channels: 1,
        interleaved: true
    )!

    // MARK: - Init

    init() {
        apiKey = Bundle.main.infoDictionary?["GEMINI_API_KEY"] as? String ?? ""

        var continuation: AsyncStream<LiveSessionState>.Continuation!
        stateStream = AsyncStream { continuation = $0 }
        stateContinuation = continuation
    }

    // MARK: - Public API

    func startSession(profile: UserProfile) async throws {
        guard !apiKey.isEmpty else {
            updateState(.error("Gemini API key is not configured."))
            throw LiveServiceError.apiKeyMissing
        }

        updateState(.connecting)

        let urlString = "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=\(apiKey)&alt=ws"
        guard let url = URL(string: urlString) else {
            updateState(.error("Could not connect to the live service."))
            throw LiveServiceError.connectionFailed
        }

        let urlSession = URLSession(configuration: .default)
        let task = urlSession.webSocketTask(with: url)
        task.resume()
        webSocketTask = task

        do {
            try await sendSetupMessage(profile: profile)
        } catch {
            task.cancel(with: .normalClosure, reason: nil)
            webSocketTask = nil
            updateState(.error("Session setup failed."))
            throw LiveServiceError.setupMessageFailed
        }

        startReceiveLoop(task: task)

        do {
            try configureAudioEngine()
        } catch {
            task.cancel(with: .normalClosure, reason: nil)
            webSocketTask = nil
            updateState(.error("Could not access the microphone."))
            throw LiveServiceError.audioSetupFailed
        }
    }

    func endSession() {
        receiveLoopTask?.cancel()
        receiveLoopTask = nil

        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil

        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }
        if playerNode.isPlaying { playerNode.stop() }
        audioConfigured = false

        deactivateAudioSession()
        updateState(.disconnected)
        stateContinuation.finish()   // ends the for-await loop in LiveSessionViewModel
    }

    // MARK: - Setup Message

    private func sendSetupMessage(profile: UserProfile) async throws {
        let systemPrompt = buildSystemPrompt(from: profile)

        let setup: [String: Any] = [
            "setup": [
                "model": "models/gemini-2.5-flash-native-audio-preview-12-2025",
                "generation_config": [
                    "response_modalities": ["audio"],
                    "speech_config": [
                        "voice_config": [
                            "prebuilt_voice_config": [
                                "voice_name": "Aoede"
                            ]
                        ]
                    ]
                ],
                "system_instruction": [
                    "parts": [["text": systemPrompt]]
                ]
            ]
        ]

        let data = try JSONSerialization.data(withJSONObject: setup)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw LiveServiceError.setupMessageFailed
        }

        #if DEBUG
        print("[GeminiLive] → setup sent")
        #endif

        try await webSocketTask?.send(.string(jsonString))
    }

    // MARK: - System Prompt

    private func buildSystemPrompt(from profile: UserProfile) -> String {
        let familyLines = profile.familyMembers
            .map { "- \($0.name) (\($0.relationship))" }
            .joined(separator: "\n")

        let memoryLines = profile.memories.map { memory -> String in
            let dateStr = memory.date.isEmpty ? "" : " [\(memory.date)]"
            return "- \(memory.title)\(dateStr): \(memory.description)"
        }.joined(separator: "\n")

        return """
        You are a warm, gentle AI companion helping \(profile.name), who lives with a memory impairment. \
        Speak as a trusted friend.

        Your role:
        - Speak in a calm, reassuring, unhurried tone.
        - Help \(profile.name) recall details with gentle questions rather than stating facts.
        - Keep responses short (2–4 sentences) unless asked for more.
        - If \(profile.name) seems confused, calmly reassure and redirect.
        - Stick strictly to the facts below. Never invent memories, names, or events.

        About \(profile.name):

        Family:
        \(familyLines)

        Cherished memories:
        \(memoryLines)

        If asked whether you are an AI, answer honestly but gently. \
        Never give medical advice. Respond only in English.
        """
    }

    // MARK: - Receive Loop

    private func startReceiveLoop(task: URLSessionWebSocketTask) {
        receiveLoopTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                do {
                    let message = try await task.receive()
                    switch message {
                    case .string(let text):
                        self.handleInboundJSON(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            self.handleInboundJSON(text)
                        }
                    @unknown default:
                        break
                    }
                } catch {
                    if !Task.isCancelled {
                        self.updateState(.error(error.localizedDescription))
                    }
                    break
                }
            }
        }
    }

    private func handleInboundJSON(_ text: String) {
        guard
            let data = text.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        #if DEBUG
        print("[GeminiLive] ← \(text.prefix(300))")
        #endif

        if json["setupComplete"] != nil {
            updateState(.listening)
            return
        }

        if let serverContent = json["serverContent"] as? [String: Any] {

            if let interrupted = serverContent["interrupted"] as? Bool, interrupted {
                if playerNode.isPlaying { playerNode.stop() }
                updateState(.interrupted)
                updateState(.listening)
                return
            }

            if let turnComplete = serverContent["turnComplete"] as? Bool, turnComplete {
                updateState(.listening)
                return
            }

            if let modelTurn = serverContent["modelTurn"] as? [String: Any],
               let parts = modelTurn["parts"] as? [[String: Any]] {
                updateState(.aiSpeaking)
                for part in parts {
                    if let inlineData = part["inlineData"] as? [String: Any],
                       let mimeType = inlineData["mimeType"] as? String,
                       mimeType.hasPrefix("audio/pcm"),
                       let b64 = inlineData["data"] as? String {
                        enqueueAudioChunk(b64)
                    }
                }
            }
        }
    }

    // MARK: - Audio Engine

    private func configureAudioEngine() throws {
        guard !audioConfigured else { return }

        let avSession = AVAudioSession.sharedInstance()
        try avSession.setCategory(
            .playAndRecord,
            mode: .voiceChat,
            options: [.defaultToSpeaker, .allowBluetoothA2DP]
        )
        try avSession.setActive(true, options: .notifyOthersOnDeactivation)

        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: playbackFormat)

        let inputNode = audioEngine.inputNode
        let nativeFormat = inputNode.outputFormat(forBus: 0)

        guard let converter = AVAudioConverter(from: nativeFormat, to: captureFormat) else {
            throw LiveServiceError.audioSetupFailed
        }

        let captureFormat = self.captureFormat

        inputNode.installTap(onBus: 0, bufferSize: 4_096, format: nativeFormat) { [weak self] buffer, _ in
            guard let self,
                  let pcmBuffer = buffer as? AVAudioPCMBuffer else { return }

            let inputFrames = pcmBuffer.frameLength
            let ratio = captureFormat.sampleRate / nativeFormat.sampleRate
            let outputFrames = AVAudioFrameCount(Double(inputFrames) * ratio)
            guard outputFrames > 0,
                  let outputBuffer = AVAudioPCMBuffer(pcmFormat: captureFormat,
                                                      frameCapacity: outputFrames)
            else { return }

            var filled = false
            converter.convert(to: outputBuffer, error: nil) { _, outStatus in
                if filled { outStatus.pointee = .noDataNow; return nil }
                filled = true
                outStatus.pointee = .haveData
                return pcmBuffer
            }

            guard let int16Data = outputBuffer.int16ChannelData,
                  outputBuffer.frameLength > 0 else { return }

            let byteCount = Int(outputBuffer.frameLength) * 2
            let rawData = Data(bytes: int16Data[0], count: byteCount)

            Task { [weak self] in await self?.sendAudioChunk(rawData) }
        }

        audioEngine.prepare()
        try audioEngine.start()
        playerNode.play()
        audioConfigured = true
    }

    private func sendAudioChunk(_ data: Data) async {
        let base64 = data.base64EncodedString()
        let message: [String: Any] = [
            "realtime_input": [
                "media_chunks": [
                    ["mime_type": "audio/pcm", "data": base64]
                ]
            ]
        ]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: message),
              let jsonString = String(data: jsonData, encoding: .utf8)
        else { return }

        try? await webSocketTask?.send(.string(jsonString))
    }

    private func enqueueAudioChunk(_ base64: String) {
        guard let data = Data(base64Encoded: base64) else { return }

        let frameCount = data.count / 2
        guard frameCount > 0,
              let pcmBuffer = AVAudioPCMBuffer(
                pcmFormat: playbackFormat,
                frameCapacity: AVAudioFrameCount(frameCount)
              ),
              let int16Ptr = pcmBuffer.int16ChannelData
        else { return }

        data.withUnsafeBytes { rawPtr in
            guard let src = rawPtr.baseAddress else { return }
            memcpy(int16Ptr[0], src, data.count)
        }
        pcmBuffer.frameLength = AVAudioFrameCount(frameCount)

        playerNode.scheduleBuffer(pcmBuffer, completionHandler: nil)
        if !playerNode.isPlaying { playerNode.play() }
    }

    private func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false,
            options: .notifyOthersOnDeactivation)
    }

    private func updateState(_ newState: LiveSessionState) {
        sessionState = newState
        stateContinuation.yield(newState)
    }
}
