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
            updateState(.error("Gemini API key is not configured."))
            throw LiveServiceError.apiKeyMissing
        }

        updateState(.connecting)

        // alt=ws is required by the Gemini Live API to enable WebSocket mode
        let urlString = "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=\(apiKey)&alt=sse"
        guard let url = URL(string: urlString) else {
            updateState(.error("Could not connect to the live service."))
            throw LiveServiceError.connectionFailed
        }

        // Open WebSocket
        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: url)
        task.resume()
        webSocketTask = task

        // Send session setup — must do this before starting receive loop
        do {
            try await sendSetupMessage(profile: profile)
        } catch {
            task.cancel(with: .normalClosure, reason: nil)
            webSocketTask = nil
            updateState(.error("Session setup failed."))
            throw LiveServiceError.setupMessageFailed
        }

        // Start receive loop — will get setupComplete before audio starts
        startReceiveLoop(task: task)

        // Configure audio engine (capture + playback)
        do {
            try configureAudioEngine()
        } catch {
            task.cancel(with: .normalClosure, reason: nil)
            webSocketTask = nil
            updateState(.error("Could not access the microphone."))
            throw LiveServiceError.audioSetupFailed
        }
    }

    /// Cleanly shuts down the session — call from `ListeningView.onDisappear`.
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

        deactivateAudioSession()
        updateState(.disconnected)
    }

    // MARK: - Setup Message
    //
    // The Gemini Live API uses camelCase JSON field names.
    // All field names must exactly match the proto field names as JSON:
    //   generationConfig (not generation_config)
    //   responseModalities (not response_modalities)
    //   speechConfig / voiceName (not nested prebuilt_voice_config)
    //   systemInstruction (not system_instruction)
    //   realtimeInput / mediaChunks (not realtime_input / media_chunks)

    private func sendSetupMessage(profile: UserProfile) async throws {
        let systemPrompt = buildSystemPrompt(from: profile)

        // Use camelCase keys exactly as the Gemini Live proto expects them
        let setup: [String: Any] = [
            "setup": [
                "model": "models/gemini-2.0-flash-live-001",
                "generationConfig": [
                    "responseModalities": ["AUDIO"],
                    "speechConfig": [
                        "voiceConfig": [
                            "prebuiltVoiceConfig": [
                                "voiceName": "Aoede"
                            ]
                        ]
                    ]
                ],
                "systemInstruction": [
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
                        await self.handleReceiveError(error)
                    }
                    break
                }
            }
        }
    }

    private func handleReceiveError(_ error: Error) {
        updateState(.error(error.localizedDescription))
    }

    private func handleInboundJSON(_ text: String) async {
        guard
            let data = text.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        // Debug: log raw response to console during development
        #if DEBUG
        print("[GeminiLive] ← \(text.prefix(300))")
        #endif

        // 1. Setup confirmation — API sends "setupComplete" as the key
        if json["setupComplete"] != nil {
            updateState(.listening)
            return
        }

        // 2. Server content — camelCase keys in responses
        if let serverContent = json["serverContent"] as? [String: Any] {

            // Interrupted — user spoke during AI response
            if let interrupted = serverContent["interrupted"] as? Bool, interrupted {
                if playerNode.isPlaying { playerNode.stop() }
                updateState(.interrupted)
                updateState(.listening)
                return
            }

            // Turn complete — AI finished its turn
            if let turnComplete = serverContent["turnComplete"] as? Bool, turnComplete {
                updateState(.listening)
                return
            }

            // Audio chunks in modelTurn.parts[].inlineData
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

    // MARK: - Audio Engine Setup

    private func configureAudioEngine() throws {
        // Configure AVAudioSession for simultaneous record + playback
        let avSession = AVAudioSession.sharedInstance()
        try avSession.setCategory(
            .playAndRecord,
            mode: .voiceChat,           // enables hardware acoustic echo cancellation
            options: [.defaultToSpeaker, .allowBluetoothA2DP]
        )
        try avSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Set up playback node before starting engine
        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: playbackFormat)

        // Install capture tap — nativeFormat is 44.1/48 kHz Float32 from hardware
        let inputNode = audioEngine.inputNode
        let nativeFormat = inputNode.outputFormat(forBus: 0)

        guard let converter = AVAudioConverter(from: nativeFormat, to: captureFormat) else {
            throw LiveServiceError.audioSetupFailed
        }

        // Capture local copies for the tap closure (avoids actor-isolation crossing)
        let captureFormat = self.captureFormat

        inputNode.installTap(onBus: 0, bufferSize: 4_096, format: nativeFormat) { [weak self] buffer, _ in
            guard let self,
                  let pcmBuffer = buffer as? AVAudioPCMBuffer else { return }

            // Convert from hardware format to 16kHz Int16 mono synchronously in tap thread
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

            let byteCount = Int(outputBuffer.frameLength) * 2   // 2 bytes per Int16
            let rawData = Data(bytes: int16Data[0], count: byteCount)

            Task { await self.sendAudioChunk(rawData) }
        }

        audioEngine.prepare()
        try audioEngine.start()
        playerNode.play()
    }

    // MARK: - Send Audio Chunk
    //
    // Outbound audio message uses camelCase:
    //   realtimeInput > mediaChunks > { mimeType, data }
    // mimeType must be "audio/pcm" (no rate suffix — rate is implied as 16kHz)

    private func sendAudioChunk(_ data: Data) async {
        let base64 = data.base64EncodedString()
        let message: [String: Any] = [
            "realtimeInput": [
                "mediaChunks": [
                    [
                        "mimeType": "audio/pcm",
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

    // MARK: - State Update (synchronous — actor guarantees mutual exclusion)

    private func updateState(_ newState: LiveSessionState) {
        sessionState = newState
        stateContinuation.yield(newState)
    }
}
