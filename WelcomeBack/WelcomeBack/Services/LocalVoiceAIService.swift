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
    private var userName = ""
    private var userProfile: UserProfile?

    // MARK: - Sentence Buffer (for streaming LLM → TTS)

    private var tokenBuffer = ""
    private var isFirstSentenceSpoken = false

    /// Maximum conversation turns to keep (user + assistant pairs).
    /// Older turns are dropped to prevent unbounded memory growth.
    private let maxConversationTurns = 16

    /// Cached image descriptions for the session (fetched once at start).
    private var sessionImageDescriptions: [String: String] = [:]

    // MARK: - Init

    init() {
        var cont: AsyncStream<LiveSessionState>.Continuation!
        stateStream = AsyncStream { cont = $0 }
        stateContinuation = cont
    }

    // MARK: - Session Lifecycle

    /// Starts a local voice session: loads the LLM, sets the system prompt,
    /// generates a warm greeting, and begins listening for speech.
    ///
    /// - Parameters:
    ///   - profile: The user's profile for building the system prompt.
    ///   - preloadedLLM: An already-loaded LLM instance (from pre-warming). If nil, loads fresh.
    func startSession(profile: UserProfile, preloadedLLM: LocalLLMService? = nil) async throws {
        #if DEBUG
        print("[LocalVoiceAI] ▶️ Starting session...")
        #endif
        updateState(.connecting)   // UI shows "Loading AI model…"

        sessionImageDescriptions = await MainActor.run { ImageDescriptionService.shared.descriptions }
        let systemPrompt = buildSystemPrompt(from: profile, imageDescriptions: sessionImageDescriptions)
        let llm: LocalLLMService

        if let preloaded = preloadedLLM, preloaded.isLoaded {
            // Use pre-warmed LLM — just set the system prompt
            #if DEBUG
            print("[LocalVoiceAI] ⚡ Using pre-warmed LLM")
            #endif
            llm = preloaded
            do {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    DispatchQueue.global(qos: .userInitiated).async {
                        do {
                            try llm.setSystemPrompt(systemPrompt)
                            continuation.resume()
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
            } catch {
                updateState(.error("Failed to set system prompt: \(error.localizedDescription)"))
                throw error
            }
        } else {
            // Load fresh — verify model is downloaded
            let config = await ModelDownloadService.shared.selectedModel
            let isReady = await ModelDownloadService.shared.isModelDownloaded(config)
            guard isReady else {
                #if DEBUG
                print("[LocalVoiceAI] ❌ Model not downloaded")
                #endif
                updateState(.error("Voice AI model not downloaded. Please download in Settings → Voice AI Model."))
                throw LocalVoiceError.modelNotDownloaded
            }

            let modelPath = await ModelDownloadService.shared.modelFileURL(for: config).path
            #if DEBUG
            print("[LocalVoiceAI] 📂 Model path: \(modelPath)")
            #endif

            let freshLLM = LocalLLMService(modelPath: modelPath, modelFamily: config.family)
            do {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    DispatchQueue.global(qos: .userInitiated).async {
                        do {
                            try freshLLM.loadModel()
                            try freshLLM.setSystemPrompt(systemPrompt)
                            continuation.resume()
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
            } catch {
                #if DEBUG
                print("[LocalVoiceAI] ❌ Model loading failed: \(error)")
                #endif
                updateState(.error("Failed to load AI model: \(error.localizedDescription)"))
                throw error
            }
            llm = freshLLM
        }

        self.llmService = llm
        self.userName = profile.name
        self.userProfile = profile
        #if DEBUG
        print("[LocalVoiceAI] ✅ LLM ready, generating greeting...")
        #endif

        // Generate a warm greeting so the AI speaks first
        await generateGreeting()

        // Begin listening after greeting finishes (or immediately if greeting fails)
    }

    /// Ends the session: stops audio, resets the model context, cleans up.
    /// The LLM stays loaded in memory so the next session starts instantly.
    /// Call `unloadLLM()` to fully release the model from memory.
    func endSession() {
        Task { @MainActor in
            SpeechService.shared.stopListening()
            SpeechService.shared.stopSpeaking()
        }
        llmService?.cancelGeneration = true
        llmService?.resetContext()  // keep model loaded, just clear KV cache
        llmService = nil
        conversationHistory.removeAll()
        sessionImageDescriptions = [:]
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
                    #if DEBUG
                    print("[LocalVoiceAI] 🎙️ Partial: \(text)")
                    #endif
                    if self.sessionState == .listening {
                        self.updateState(.userSpeaking)
                    }
                },
                onSilenceDetected: { [weak self] in
                    guard let self else { return }
                    #if DEBUG
                    print("[LocalVoiceAI] 🔇 Silence detected")
                    #endif
                    if self.sessionState == .userSpeaking {
                        self.updateState(.aiThinking)
                    }
                },
                onFinalResult: { [weak self] finalText in
                    #if DEBUG
                    print("[LocalVoiceAI] 📝 Final result: '\(finalText)'")
                    #endif
                    guard let self, !finalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        #if DEBUG
                        print("[LocalVoiceAI] ⚠️ Final text was empty, skipping")
                        #endif
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
            #if DEBUG
            print("[LocalVoiceAI] ⚠️ Already processing, skipping")
            #endif
            return
        }
        isProcessing = true
        #if DEBUG
        print("[LocalVoiceAI] 🧠 Processing user input: '\(text)'")
        #endif

        updateState(.aiThinking)

        // Stop listening while we process
        await MainActor.run {
            SpeechService.shared.stopListening()
        }

        // Add user turn to conversation history
        conversationHistory.append((role: "user", content: text))

        // Trim conversation history if it's getting too long
        if conversationHistory.count > maxConversationTurns {
            let excess = conversationHistory.count - maxConversationTurns
            conversationHistory.removeFirst(excess)
            #if DEBUG
            print("[LocalVoiceAI] 🔄 Trimmed \(excess) old conversation turns")
            #endif
        }

        // Stream LLM response
        guard let llm = llmService else {
            #if DEBUG
            print("[LocalVoiceAI] ❌ llmService is nil!")
            #endif
            isProcessing = false
            return
        }

        // Trim context proactively BEFORE generation to ensure space
        llm.trimContextIfNeeded()

        tokenBuffer = ""
        isFirstSentenceSpoken = false
        var fullResponse = ""
        var tokenCount = 0
        let generationStartTime = Date()
        var receivedFirstToken = false

        #if DEBUG
        print("[LocalVoiceAI] 📤 Sending to LLM: '\(text)'")
        #endif

        for await token in llm.generateResponse(userMessage: text) {
            if !receivedFirstToken {
                receivedFirstToken = true
                let latency = Date().timeIntervalSince(generationStartTime)
                #if DEBUG
                print("[LocalVoiceAI] ⏱️ First token latency: \(String(format: "%.2f", latency))s")
                #endif
            }

            tokenCount += 1
            fullResponse += token
            tokenBuffer += token
            #if DEBUG
            if tokenCount <= 10 {
                print("[LocalVoiceAI] 🔤 Token \(tokenCount): '\(token)'")
            }
            #endif

            // Detect sentence boundaries: . ! ? optionally followed by whitespace
            // Also break on commas/semicolons if the buffer is getting long (20+ words)
            let wordCount = tokenBuffer.split(separator: " ").count
            let pattern: String
            if wordCount >= 20 {
                // Allow clause-level breaks for faster TTS start
                pattern = #"[.!?,;][\"'\u{201D}\u{2019}]?[\s]*"#
            } else {
                pattern = #"[.!?][\"'\u{201D}\u{2019}]?[\s]*"#
            }
            while let range = tokenBuffer.range(of: pattern, options: .regularExpression) {
                let sentence = String(tokenBuffer[tokenBuffer.startIndex..<range.upperBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                tokenBuffer = String(tokenBuffer[range.upperBound...])

                guard !sentence.isEmpty else { continue }
                #if DEBUG
                print("[LocalVoiceAI] 💬 Sentence ready: '\(sentence)'")
                #endif

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
                #if DEBUG
                print("[LocalVoiceAI] ⏰ Generation timeout after 45s")
                #endif
                llm.cancelGeneration = true
                break
            }
        }

        let totalTime = Date().timeIntervalSince(generationStartTime)
        #if DEBUG
        print("[LocalVoiceAI] 📊 Generation done: \(tokenCount) tokens in \(String(format: "%.1f", totalTime))s, response: '\(fullResponse.prefix(200))'")
        #endif

        // Flush remaining buffer
        let remaining = tokenBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !remaining.isEmpty {
            #if DEBUG
            print("[LocalVoiceAI] 💬 Flushing remaining buffer: '\(remaining)'")
            #endif
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
            #if DEBUG
            print("[LocalVoiceAI] ❌ No tokens generated! receivedFirstToken=\(receivedFirstToken)")
            #endif
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

        isProcessing = false
    }

    // MARK: - Warm Greeting

    /// Generates a short greeting so the AI speaks first when the session starts.
    private func generateGreeting() async {
        guard let llm = llmService else { return }

        let greetingPrompt = "Greet \(userName) warmly in 1 short sentence. Be natural and friendly."
        let greeting = await llm.generateResponse(userMessage: greetingPrompt)
            .reduce("", +)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !greeting.isEmpty else {
            #if DEBUG
            print("[LocalVoiceAI] ⚠️ Greeting was empty, skipping")
            #endif
            updateState(.listening)
            await MainActor.run { [weak self] in
                self?.startListeningCycle()
            }
            return
        }

        #if DEBUG
        print("[LocalVoiceAI] 👋 Greeting: '\(greeting)'")
        #endif
        conversationHistory.append((role: "assistant", content: greeting))
        updateState(.aiSpeaking)

        await MainActor.run { [weak self] in
            SpeechService.shared.speakSentences([greeting]) { [weak self] in
                self?.onAllSpeechFinished()
            }
        }
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

    /// Stop words to exclude from relevance scoring.
    private static let stopWords: Set<String> = [
        "the", "a", "an", "is", "are", "was", "were", "be", "been", "being",
        "have", "has", "had", "do", "does", "did", "will", "would", "could",
        "should", "may", "might", "shall", "can", "to", "of", "in", "for",
        "on", "with", "at", "by", "from", "as", "into", "about", "like",
        "through", "after", "over", "between", "out", "up", "down", "and",
        "but", "or", "nor", "not", "no", "so", "if", "than", "too", "very",
        "just", "that", "this", "it", "i", "me", "my", "we", "you", "your",
        "he", "she", "they", "them", "what", "which", "who", "when", "where",
        "how", "all", "each", "every", "both", "few", "more", "most", "some",
        "tell", "know", "think", "say", "said", "get", "go", "come", "make",
    ]

    /// Scores a text block against a set of query keywords.
    private func relevanceScore(text: String, keywords: Set<String>) -> Int {
        let words = Set(text.lowercased().split(separator: " ").map { String($0) })
        return words.intersection(keywords).count
    }

    /// Selects the most relevant family members and memories based on the user's query.
    private func selectRelevantContent(
        query: String,
        profile: UserProfile,
        imageDescriptions: [String: String]
    ) -> (members: [FamilyMember], memories: [Memory]) {
        let keywords = Set(
            query.lowercased()
                .components(separatedBy: .alphanumerics.inverted)
                .filter { !$0.isEmpty && !Self.stopWords.contains($0) }
        )

        // If no meaningful keywords or first turn, include everything
        guard !keywords.isEmpty else {
            return (profile.familyMembers, profile.memories)
        }

        // Score family members
        let scoredMembers = profile.familyMembers.map { member -> (FamilyMember, Int) in
            let text = [
                member.name, member.relationship, member.biography,
                member.memory1, member.memory2,
                imageDescriptions[member.imageURL] ?? ""
            ].joined(separator: " ")
            return (member, relevanceScore(text: text, keywords: keywords))
        }.sorted { $0.1 > $1.1 }

        // Score memories
        let scoredMemories = profile.memories.map { memory -> (Memory, Int) in
            let text = [
                memory.title, memory.description,
                imageDescriptions[memory.imageURL] ?? ""
            ].joined(separator: " ")
            return (memory, relevanceScore(text: text, keywords: keywords))
        }.sorted { $0.1 > $1.1 }

        // Take top-3 members (or all if scored), top-4 memories
        let topMembers = scoredMembers.prefix(3).map(\.0)
        let topMemories = scoredMemories.prefix(4).map(\.0)

        return (Array(topMembers), Array(topMemories))
    }

    /// Builds a rich system prompt from the user's profile.
    /// When a query is provided, prioritizes relevant memories and family members.
    private func buildSystemPrompt(
        from profile: UserProfile,
        relevantQuery: String? = nil,
        imageDescriptions: [String: String] = [:]
    ) -> String {
        let imageDescs = imageDescriptions

        let (relevantMembers, relevantMemories): ([FamilyMember], [Memory])
        if let query = relevantQuery {
            (relevantMembers, relevantMemories) = selectRelevantContent(
                query: query, profile: profile, imageDescriptions: imageDescs
            )
        } else {
            relevantMembers = profile.familyMembers
            relevantMemories = profile.memories
        }

        let relevantMemberIDs = Set(relevantMembers.map(\.id))

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

        // Family members — full details for relevant ones, brief for others
        if !profile.familyMembers.isEmpty {
            prompt += "\nTheir family:\n"
            for member in profile.familyMembers {
                if relevantMemberIDs.contains(member.id) {
                    // Full details for relevant members
                    prompt += "- \(member.name) (\(member.relationship))"
                    if !member.phone.isEmpty {
                        prompt += ", phone: \(member.phone)"
                    }
                    prompt += "\n"
                    if let photoDesc = imageDescs[member.imageURL], photoDesc != "photo" {
                        prompt += "  [Photo: \(photoDesc)]\n"
                    }
                    if !member.biography.isEmpty {
                        prompt += "  About: \(member.biography)\n"
                    }
                    if !member.memory1.isEmpty {
                        prompt += "  Memory: \(member.memory1)\n"
                    }
                    if !member.memory2.isEmpty {
                        prompt += "  Memory: \(member.memory2)\n"
                    }
                } else {
                    // Brief mention for non-relevant members
                    prompt += "- \(member.name) (\(member.relationship))\n"
                }
            }
        }

        // Memories — full details for relevant ones
        if !relevantMemories.isEmpty {
            prompt += "\nKey memories and places they love:\n"
            for memory in relevantMemories {
                let dateStr = memory.date.isEmpty ? "" : " [\(memory.date)]"
                prompt += "- \(memory.title)\(dateStr): \(memory.description)"
                if let photoDesc = imageDescs[memory.imageURL], photoDesc != "photo" {
                    prompt += " [Photo: \(photoDesc)]"
                }
                prompt += "\n"
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
