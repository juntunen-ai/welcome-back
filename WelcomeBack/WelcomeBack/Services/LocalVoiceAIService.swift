import Foundation
import AVFoundation

/// Orchestrates the fully local voice AI pipeline: STT → LLM → TTS.
///
/// Uses the same `AsyncStream<LiveSessionState>` pattern as `GeminiLiveService`
/// so the view model and UI layer can be shared between cloud and local modes.
final class LocalVoiceAIService: @unchecked Sendable {

    // MARK: - State Stream

    let stateStream: AsyncStream<LiveSessionState>
    private let stateContinuation: AsyncStream<LiveSessionState>.Continuation
    private(set) var sessionState: LiveSessionState = .idle

    // MARK: - Dependencies

    private var llmService: LocalLLMService?

    // MARK: - Conversation

    private var conversationHistory: [(role: String, content: String)] = []
    private var currentTranscription = ""
    private var isProcessing = false

    // MARK: - Sentence Buffer (for streaming LLM → TTS)

    private var tokenBuffer = ""
    private var isFirstSentenceSpoken = false

    // MARK: - Init

    init() {
        var cont: AsyncStream<LiveSessionState>.Continuation!
        stateStream = AsyncStream { cont = $0 }
        stateContinuation = cont
    }

    // MARK: - Session Lifecycle

    /// Starts a local voice session: loads the LLM, sets the system prompt,
    /// and begins listening for speech.
    func startSession(profile: UserProfile) async throws {
        print("[LocalVoiceAI] ▶️ Starting session...")
        updateState(.connecting)   // UI shows "Loading AI model…"

        // 1. Verify model is downloaded
        let config = await ModelDownloadService.shared.selectedModel
        let isReady = await ModelDownloadService.shared.isModelDownloaded(config)
        guard isReady else {
            print("[LocalVoiceAI] ❌ Model not downloaded")
            updateState(.error("Voice AI model not downloaded. Please download in Settings → Voice AI Model."))
            throw LocalVoiceError.modelNotDownloaded
        }

        // 2. Gather info we need from MainActor
        let modelPath = await ModelDownloadService.shared.modelFileURL(for: config).path
        let systemPrompt = buildSystemPrompt(from: profile)
        print("[LocalVoiceAI] 📂 Model path: \(modelPath)")
        print("[LocalVoiceAI] 📝 System prompt: \(systemPrompt.prefix(100))...")

        // 3. Load LLM on a real thread with a full 8 MB stack.
        //    Swift Task.detached only gets ~64 KB stack, which causes stack overflow
        //    inside llama.cpp's C code during model loading.
        let llm = LocalLLMService(modelPath: modelPath)
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        try llm.loadModel()
                        print("[LocalVoiceAI] ✅ Model loaded, setting system prompt...")
                        try llm.setSystemPrompt(systemPrompt)
                        print("[LocalVoiceAI] ✅ System prompt set")
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        } catch {
            print("[LocalVoiceAI] ❌ Model loading failed: \(error)")
            updateState(.error("Failed to load AI model: \(error.localizedDescription)"))
            throw error
        }

        self.llmService = llm
        print("[LocalVoiceAI] 🎤 Starting listening cycle...")

        // 4. Begin listening
        updateState(.listening)
        await startListeningCycle()
    }

    /// Ends the session: stops audio, unloads the model, cleans up.
    func endSession() {
        Task { @MainActor in
            SpeechService.shared.stopListening()
            SpeechService.shared.stopSpeaking()
        }
        llmService?.cancelGeneration = true
        llmService?.unloadModel()
        llmService = nil
        conversationHistory.removeAll()
        updateState(.disconnected)
        stateContinuation.finish()
    }

    // MARK: - Listening Cycle

    @MainActor
    private func startListeningCycle() {
        do {
            try SpeechService.shared.startListeningWithVAD(
                silenceThreshold: 1.5,
                onPartialResult: { [weak self] text in
                    guard let self else { return }
                    self.currentTranscription = text
                    print("[LocalVoiceAI] 🎙️ Partial: \(text)")
                    if self.sessionState == .listening {
                        self.updateState(.userSpeaking)
                    }
                },
                onSilenceDetected: { [weak self] in
                    guard let self else { return }
                    print("[LocalVoiceAI] 🔇 Silence detected")
                    if self.sessionState == .userSpeaking {
                        self.updateState(.aiThinking)
                    }
                },
                onFinalResult: { [weak self] finalText in
                    print("[LocalVoiceAI] 📝 Final result: '\(finalText)'")
                    guard let self, !finalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        print("[LocalVoiceAI] ⚠️ Final text was empty, skipping")
                        return
                    }
                    Task {
                        await self.processUserInput(finalText)
                    }
                }
            )
        } catch {
            updateState(.error("Could not start listening: \(error.localizedDescription)"))
        }
    }

    // MARK: - Process User Input → LLM → TTS

    private func processUserInput(_ text: String) async {
        guard !isProcessing else {
            print("[LocalVoiceAI] ⚠️ Already processing, skipping")
            return
        }
        isProcessing = true
        print("[LocalVoiceAI] 🧠 Processing user input: '\(text)'")

        updateState(.aiThinking)

        // Stop listening while we process
        await MainActor.run {
            SpeechService.shared.stopListening()
        }

        // Add user turn to conversation history
        conversationHistory.append((role: "user", content: text))

        // Stream LLM response
        guard let llm = llmService else {
            print("[LocalVoiceAI] ❌ llmService is nil!")
            isProcessing = false
            return
        }

        tokenBuffer = ""
        isFirstSentenceSpoken = false
        var fullResponse = ""
        var tokenCount = 0
        let generationStartTime = Date()
        var receivedFirstToken = false

        print("[LocalVoiceAI] 📤 Sending to LLM: '\(text)'")

        for await token in llm.generateResponse(userMessage: text) {
            if !receivedFirstToken {
                receivedFirstToken = true
                let latency = Date().timeIntervalSince(generationStartTime)
                print("[LocalVoiceAI] ⏱️ First token latency: \(String(format: "%.2f", latency))s")
            }

            tokenCount += 1
            fullResponse += token
            tokenBuffer += token
            if tokenCount <= 10 {
                print("[LocalVoiceAI] 🔤 Token \(tokenCount): '\(token)'")
            }

            // Detect sentence boundaries: . ! ? optionally followed by whitespace
            while let range = tokenBuffer.range(of: #"[.!?][\"'\u{201D}\u{2019}]?[\s]*"#, options: .regularExpression) {
                let sentence = String(tokenBuffer[tokenBuffer.startIndex..<range.upperBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                tokenBuffer = String(tokenBuffer[range.upperBound...])

                guard !sentence.isEmpty else { continue }
                print("[LocalVoiceAI] 💬 Sentence ready: '\(sentence)'")

                if !isFirstSentenceSpoken {
                    isFirstSentenceSpoken = true
                    updateState(.aiSpeaking)
                    await MainActor.run { [weak self] in
                        SpeechService.shared.speakSentences([sentence]) { [weak self] in
                            self?.onAllSpeechFinished()
                        }
                    }
                } else {
                    await MainActor.run {
                        SpeechService.shared.enqueueSentence(sentence)
                    }
                }
            }

            // Timeout: if generation is taking too long (>45s total), stop
            if Date().timeIntervalSince(generationStartTime) > 45 {
                print("[LocalVoiceAI] ⏰ Generation timeout after 45s")
                llm.cancelGeneration = true
                break
            }
        }

        let totalTime = Date().timeIntervalSince(generationStartTime)
        print("[LocalVoiceAI] 📊 Generation done: \(tokenCount) tokens in \(String(format: "%.1f", totalTime))s, response: '\(fullResponse.prefix(200))'")

        // Flush remaining buffer
        let remaining = tokenBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !remaining.isEmpty {
            print("[LocalVoiceAI] 💬 Flushing remaining buffer: '\(remaining)'")
            if !isFirstSentenceSpoken {
                isFirstSentenceSpoken = true
                updateState(.aiSpeaking)
                await MainActor.run { [weak self] in
                    SpeechService.shared.speakSentences([remaining]) { [weak self] in
                        self?.onAllSpeechFinished()
                    }
                }
            } else {
                await MainActor.run {
                    SpeechService.shared.enqueueSentence(remaining)
                }
            }
        }

        // If nothing was generated at all, show error and go back to listening
        if fullResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            print("[LocalVoiceAI] ❌ No tokens generated! receivedFirstToken=\(receivedFirstToken)")
            isProcessing = false
            if !receivedFirstToken {
                updateState(.error("No response from AI. Please try again."))
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
            updateState(.listening)
            await MainActor.run { [weak self] in
                self?.startListeningCycle()
            }
            return
        }

        // Save assistant response
        conversationHistory.append((role: "assistant", content: fullResponse))

        // Trim context if approaching limit
        llm.trimContextIfNeeded()

        isProcessing = false
    }

    /// Called when TTS finishes all queued sentences → restart listening.
    private func onAllSpeechFinished() {
        guard sessionState != .disconnected else { return }
        updateState(.listening)
        Task { @MainActor [weak self] in
            self?.startListeningCycle()
        }
    }

    // MARK: - System Prompt Builder

    /// Builds a rich system prompt from the user's profile, including full
    /// biographies, personal memories, address, and location.
    private func buildSystemPrompt(from profile: UserProfile) -> String {
        var prompt = """
        You are a friendly, warm companion talking with \(profile.name). \
        Chat naturally like a good friend would — relaxed, curious, unhurried.

        """

        if !profile.biography.isEmpty {
            prompt += "\(profile.name) is \(profile.biography)\n"
        }
        if !profile.address.isEmpty {
            prompt += "They live at \(profile.address)"
            if !profile.currentLocation.isEmpty {
                prompt += " in \(profile.currentLocation)"
            }
            prompt += ".\n"
        }

        // Family members — include full biographies and personal memories
        if !profile.familyMembers.isEmpty {
            prompt += "\nTheir family:\n"
            for member in profile.familyMembers {
                prompt += "- \(member.name) (\(member.relationship))"
                if !member.phone.isEmpty {
                    prompt += ", phone: \(member.phone)"
                }
                prompt += "\n"
                if !member.biography.isEmpty {
                    prompt += "  About: \(member.biography)\n"
                }
                if !member.memory1.isEmpty {
                    prompt += "  Memory: \(member.memory1)\n"
                }
                if !member.memory2.isEmpty {
                    prompt += "  Memory: \(member.memory2)\n"
                }
            }
        }

        // Memories
        if !profile.memories.isEmpty {
            prompt += "\nKey memories and places they love:\n"
            for memory in profile.memories {
                let dateStr = memory.date.isEmpty ? "" : " [\(memory.date)]"
                prompt += "- \(memory.title)\(dateStr): \(memory.description)\n"
            }
        }

        prompt += """

        Guidelines:
        - Be conversational, warm, and unhurried. Don't sound like a helper or assistant.
        - Follow \(profile.name)'s lead: if they want to chat about something, go with it.
        - Keep replies to 2-4 sentences unless they ask for more.
        - If they seem unsure about something, gently offer a detail or ask a light question — never make them feel tested.
        - Use the facts above as a natural backdrop, not a script. Bring them up when relevant.
        - Never invent names, people, or events beyond what's listed.
        - If asked whether you are an AI, answer honestly but warmly.
        - Never give medical advice.
        """

        return prompt
    }

    // MARK: - Private

    private func updateState(_ newState: LiveSessionState) {
        sessionState = newState
        stateContinuation.yield(newState)
    }
}

// MARK: - Errors

enum LocalVoiceError: LocalizedError {
    case modelNotDownloaded
    case modelLoadFailed
    case sessionFailed

    var errorDescription: String? {
        switch self {
        case .modelNotDownloaded: return "Voice AI model not downloaded."
        case .modelLoadFailed:    return "Failed to load voice AI model."
        case .sessionFailed:      return "Voice session failed."
        }
    }
}
