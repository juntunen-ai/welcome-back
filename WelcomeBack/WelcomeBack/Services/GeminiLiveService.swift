import Foundation
import AVFoundation

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
/// Streams 16 kHz PCM audio from the device microphone to Gemini and plays back
/// 24 kHz PCM audio received from Gemini in real time.
///
/// State changes are published via `stateStream` — subscribe in
/// `LiveSessionViewModel` to drive the UI.
actor GeminiLiveService {

    // MARK: - Singleton

    static let shared = GeminiLiveService()

    // MARK: - State stream (AsyncStream bridges actor → @MainActor)

    let stateStream: AsyncStream<LiveSessionState>
    private let stateContinuation: AsyncStream<LiveSessionState>.Continuation

    private(set) var sessionState: LiveSessionState = .idle

    // MARK: - Private state

    private let apiKey: String
    private var webSocketTask: URLSessionWebSocketTask?
    private var receiveLoopTask: Task<Void, Never>?

    // MARK: - Audio engine (shared for capture + playback)

    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()

    /// Target capture format: 16 kHz, Int16, mono — required by Gemini Live
    private let captureFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 16_000,
        channels: 1,
        interleaved: true
    )!

    /// Playback format: 24 kHz, Int16, mono — as returned by Gemini Live
    private let playbackFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 24_000,
        channels: 1,
        interleaved: true
    )!

    // MARK: - Init

    private init() {
        apiKey = Bundle.main.infoDictionary?["GEMINI_API_KEY"] as? String ?? ""

        var continuation: AsyncStream<LiveSessionState>.Continuation!
        stateStream = AsyncStream { continuation = $0 }
        stateContinuation = continuation
    }

    // MARK: - Public API

    /// Opens a WebSocket session, sends the setup message, and starts audio capture.
    /// Throws `LiveServiceError` if the key is missing or connection fails.
    func startSession(profile: UserProfile) async throws {
        guard !apiKey.isEmpty else {
            await updateState(.error(LiveServiceError.apiKeyMissing.localizedDescription!))
            throw LiveServiceError.apiKeyMissing
        }

        await updateState(.connecting)

        // Build WebSocket URL
        let urlString = "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            await updateState(.error(LiveServiceError.connectionFailed.localizedDescription!))
            throw LiveServiceError.connectionFailed
        }

        // Open WebSocket
        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: url)
        task.resume()
        webSocketTask = task

        // Send session setup
        do {
            try await sendSetupMessage(profile: profile)
        } catch {
            task.cancel(with: .normalClosure, reason: nil)
            webSocketTask = nil
            await updateState(.error(LiveServiceError.setupMessageFailed.localizedDescription!))
            throw LiveServiceError.setupMessageFailed
        }

        // Start receive loop
        startReceiveLoop(task: task)

        // Configure audio engine (capture + playback)
        do {
            try configureAudioEngine()
        } catch {
            task.cancel(with: .normalClosure, reason: nil)
            webSocketTask = nil
            await updateState(.error(LiveServiceError.audioSetupFailed.localizedDescription!))
            throw LiveServiceError.audioSetupFailed
        }
    }

    /// Cleanly shuts down the session — call from `ListeningView.onDisappear`.
    func endSession() async {
        receiveLoopTask?.cancel()
        receiveLoopTask = nil

        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil

        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }
        if playerNode.isPlaying { playerNode.stop() }

        deactivateAudioSession()
        await updateState(.disconnected)
    }

    // MARK: - Setup Message

    private func sendSetupMessage(profile: UserProfile) async throws {
        let systemPrompt = buildSystemPrompt(from: profile)

        let setup: [String: Any] = [
            "setup": [
                "model": "models/gemini-2.0-flash-live-preview",
                "generation_config": [
                    "response_modalities": ["AUDIO"],
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
        Your name does not matter — speak as a trusted friend.

        Your role:
        - Speak in a calm, reassuring, unhurried tone. Never clinical, never rushed.
        - Gently guide \(profile.name) to recall details themselves with soft questions \
        rather than stating facts outright.
        - Keep responses short (2–4 sentences) unless \(profile.name) explicitly asks for more.
        - If \(profile.name) seems confused or distressed, calmly reassure and redirect.
        - Never contradict, correct sharply, or express surprise at repeated questions.
        - Stick strictly to the facts below. Do NOT invent memories, names, or events.

        About \(profile.name):

        Family:
        \(familyLines)

        Cherished memories:
        \(memoryLines)

        If directly asked whether you are an AI, answer honestly but gently. \
        Never give medical advice or diagnoses. Respond only in English.
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
                        await self.handleInboundJSON(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            await self.handleInboundJSON(text)
                        }
                    @unknown default:
                        break
                    }
                } catch {
                    if !Task.isCancelled {
                        await self.updateState(.error(error.localizedDescription))
                    }
                    break
                }
            }
        }
    }

    private func handleInboundJSON(_ text: String) async {
        guard
            let data = text.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        // 1. Setup confirmation
        if json["setupComplete"] != nil {
            await updateState(.listening)
            return
        }

        // 2. Server content
        if let serverContent = json["serverContent"] as? [String: Any] {

            // Interrupted — Harri spoke mid-response
            if let interrupted = serverContent["interrupted"] as? Bool, interrupted {
                if playerNode.isPlaying { playerNode.stop() }
                await updateState(.interrupted)
                // Immediately return to listening after interruption
                await updateState(.listening)
                return
            }

            // Turn complete — AI finished speaking
            if let turnComplete = serverContent["turnComplete"] as? Bool, turnComplete {
                await updateState(.listening)
                return
            }

            // Audio chunks from model turn
            if let modelTurn = serverContent["modelTurn"] as? [String: Any],
               let parts = modelTurn["parts"] as? [[String: Any]] {
                await updateState(.aiSpeaking)
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

    // MARK: - Audio Engine Setup

    private func configureAudioEngine() throws {
        // Configure AVAudioSession for simultaneous record + playback
        let avSession = AVAudioSession.sharedInstance()
        try avSession.setCategory(
            .playAndRecord,
            mode: .voiceChat,          // enables hardware echo cancellation
            options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]
        )
        try avSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Set up playback node
        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: playbackFormat)

        // Install capture tap
        let inputNode = audioEngine.inputNode
        let nativeFormat = inputNode.outputFormat(forBus: 0)

        guard let converter = AVAudioConverter(from: nativeFormat, to: captureFormat) else {
            throw LiveServiceError.audioSetupFailed
        }

        inputNode.installTap(onBus: 0, bufferSize: 4_096, format: nativeFormat) { [weak self] buffer, _ in
            guard let self else { return }
            Task { await self.convertAndSend(buffer: buffer, converter: converter, sourceFormat: nativeFormat) }
        }

        audioEngine.prepare()
        try audioEngine.start()
        playerNode.play()
    }

    // MARK: - Capture: Convert and Send

    private func convertAndSend(
        buffer: AVAudioBuffer,
        converter: AVAudioConverter,
        sourceFormat: AVAudioFormat
    ) async {
        guard let pcmBuffer = buffer as? AVAudioPCMBuffer else { return }

        let inputFrames = pcmBuffer.frameLength
        let ratio = captureFormat.sampleRate / sourceFormat.sampleRate
        let outputFrames = AVAudioFrameCount(Double(inputFrames) * ratio)

        guard outputFrames > 0,
              let outputBuffer = AVAudioPCMBuffer(pcmFormat: captureFormat, frameCapacity: outputFrames)
        else { return }

        var conversionError: NSError?
        var filled = false

        converter.convert(to: outputBuffer, error: &conversionError) { _, outStatus in
            if filled {
                outStatus.pointee = .noDataNow
                return nil
            }
            filled = true
            outStatus.pointee = .haveData
            return pcmBuffer
        }

        guard conversionError == nil,
              let int16Data = outputBuffer.int16ChannelData,
              outputBuffer.frameLength > 0
        else { return }

        let byteCount = Int(outputBuffer.frameLength) * 2   // 2 bytes per Int16
        let rawData = Data(bytes: int16Data[0], count: byteCount)
        await sendAudioChunk(rawData)
    }

    private func sendAudioChunk(_ data: Data) async {
        let base64 = data.base64EncodedString()
        let message: [String: Any] = [
            "realtime_input": [
                "media_chunks": [
                    [
                        "mime_type": "audio/pcm;rate=16000",
                        "data": base64
                    ]
                ]
            ]
        ]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: message),
              let jsonString = String(data: jsonData, encoding: .utf8)
        else { return }

        try? await webSocketTask?.send(.string(jsonString))
    }

    // MARK: - Playback: Enqueue Audio Chunk

    private func enqueueAudioChunk(_ base64: String) {
        guard let data = Data(base64Encoded: base64) else { return }

        let frameCount = data.count / 2   // 2 bytes per Int16 sample
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

    // MARK: - Audio Session Cleanup

    private func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - State Update

    private func updateState(_ newState: LiveSessionState) {
        sessionState = newState
        stateContinuation.yield(newState)
    }
}
