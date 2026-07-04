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

    /// The conversation language (from the app's language setting), captured at
    /// session start. Drives the LLM's response language and the greeting so the
    /// AI always speaks the user's language regardless of the device language or
    /// the language the profile facts are written in.
    private var sessionLanguage: AppLanguage = .english

    /// Consecutive empty/garbled transcriptions, to avoid a re-engagement loop in noise.
    private var consecutiveEmptyFinals = 0

    /// Set when the user taps "That's enough" — suppresses any further TTS
    /// for the current reply while the generation loop unwinds.
    private var stopRequested = false

    /// Fires after a stretch of `.listening` with no speech at all, so a silent
    /// user (dozed off, walked away, unsure it's their turn) gets a warm nudge
    /// instead of a mic that stays hot forever.
    private var idleTimer: Timer?
    /// 0 = none sent; 1 = invitation sent; 2 = wind-down sent (session ends).
    private var idleNudgesSent = 0
    private let idleNudgeInterval: TimeInterval = 40

    // MARK: - Sentence Buffer (for streaming LLM → TTS)

    private var tokenBuffer = ""
    private var isFirstSentenceSpoken = false

    /// Maximum conversation turns to keep (user + assistant pairs).
    /// Older turns are dropped to prevent unbounded memory growth.
    /// With 2048 context window, we can keep more conversation history.
    private let maxConversationTurns = 24

    /// Tracks whether the greeting has finished so we can overlap listening.
    private var greetingFinished = false

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
        let modelConfig = await ModelDownloadService.shared.selectedModel
        #if DEBUG
        dprint("[LocalVoiceAI] ▶️ Starting session with model: \(modelConfig.name) (id=\(modelConfig.id), family=\(modelConfig.family))")
        #endif
        updateState(.connecting)   // UI shows "Loading AI model…"

        sessionImageDescriptions = await MainActor.run { ImageDescriptionService.shared.descriptions }
        sessionLanguage = await MainActor.run { LanguageManager.shared.language }
        #if DEBUG
        dprint("[LocalVoiceAI] 🌐 Conversation language: \(sessionLanguage.englishName)")
        #endif
        let systemPrompt = buildSystemPrompt(from: profile, imageDescriptions: sessionImageDescriptions)
        let llm: LocalLLMService

        if let preloaded = preloadedLLM, preloaded.isLoaded {
            // Use pre-warmed LLM — just set the system prompt
            #if DEBUG
            dprint("[LocalVoiceAI] ⚡ Using pre-warmed LLM")
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
                dprint("[LocalVoiceAI] ❌ Model not downloaded")
                #endif
                updateState(.error("Voice AI model not downloaded. Please download in Settings → Voice AI Model."))
                throw LocalVoiceError.modelNotDownloaded
            }

            let modelPath = await ModelDownloadService.shared.modelFileURL(for: config).path
            #if DEBUG
            dprint("[LocalVoiceAI] 📂 Model path: \(modelPath)")
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
                dprint("[LocalVoiceAI] ❌ Model loading failed: \(error)")
                #endif
                updateState(.error("Failed to load AI model: \(error.localizedDescription)"))
                throw error
            }
            llm = freshLLM
        }

        self.llmService = llm
        self.userName = profile.name
        self.userProfile = profile
        self.greetingFinished = false
        #if DEBUG
        dprint("[LocalVoiceAI] ✅ LLM ready, generating greeting...")
        #endif

        // Generate greeting and start listening concurrently —
        // don't wait for TTS to finish before the user can speak
        await generateGreeting()
    }

    /// Ends the session: stops audio, resets the model context, cleans up.
    /// The LLM stays loaded in memory so the next session starts instantly.
    /// Call `unloadLLM()` to fully release the model from memory.
    func endSession() {
        idleTimer?.invalidate()
        idleTimer = nil
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

    // MARK: - Tap-to-Stop

    /// User tapped "That's enough" while the AI was talking (or thinking).
    /// Stops the reply immediately and returns to listening — without ending
    /// the whole session, which used to be the only escape from a long reply.
    func stopCurrentReply() {
        guard sessionState == .aiSpeaking || sessionState == .aiThinking else { return }
        #if DEBUG
        dprint("[LocalVoiceAI] ✋ User stopped the current reply")
        #endif
        stopRequested = true
        llmService?.cancelGeneration = true
        Task { @MainActor [weak self] in
            SpeechService.shared.stopSpeaking()   // clears queue + completion callback
            guard let self, self.sessionState != .disconnected else { return }
            self.updateState(.listening)
            self.startListeningCycle()
        }
    }

    // MARK: - Idle Re-engagement

    /// (Re)arms the idle timer for the current listening stretch.
    @MainActor
    private func armIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: idleNudgeInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.idleTimerFired()
            }
        }
    }

    /// No speech at all for a whole idle interval while listening.
    /// First time: a warm, no-pressure invitation. Second time: offer to rest
    /// and wind the session down gracefully instead of staying hot forever.
    @MainActor
    private func idleTimerFired() {
        guard sessionState == .listening, !isProcessing else { return }
        idleNudgesSent += 1

        // Half-duplex: mic must be off while we speak the nudge.
        SpeechService.shared.stopListening()

        if idleNudgesSent <= 1 {
            let line = sessionLanguage == .finnish
                ? "Olen tässä, kun haluat jutella."
                : "I'm here whenever you feel like talking."
            updateState(.aiSpeaking)
            SpeechService.shared.speakSentences([line]) { [weak self] in
                self?.onAllSpeechFinished()   // restarts listening + idle timer
            }
        } else {
            let line = sessionLanguage == .finnish
                ? "Levätäänkö hetki? Voimme jutella taas milloin vain haluat."
                : "Shall we rest for a little while? We can talk again whenever you like."
            updateState(.aiSpeaking)
            SpeechService.shared.speakSentences([line]) { [weak self] in
                self?.endSession()   // graceful wind-down; view dismisses on .disconnected
            }
        }
    }

    // MARK: - Listening Cycle

    @MainActor
    private func startListeningCycle() {
        do {
            try SpeechService.shared.startListeningWithVAD(
                // Elderly / memory-support speakers pause longer mid-recall; a short
                // cutoff cuts them off. ~3s lets them finish their thought.
                silenceThreshold: 3.0,
                onPartialResult: { [weak self] text in
                    guard let self else { return }
                    self.currentTranscription = text
                    #if DEBUG
                    dprint("[LocalVoiceAI] 🎙️ Partial: \(text)")
                    #endif
                    if !text.isEmpty {
                        // The user is talking — they're not idle.
                        self.idleTimer?.invalidate()
                        self.idleTimer = nil
                        self.idleNudgesSent = 0
                    }
                    if self.sessionState == .listening {
                        self.updateState(.userSpeaking)
                    }
                },
                onSilenceDetected: { [weak self] in
                    guard let self else { return }
                    #if DEBUG
                    dprint("[LocalVoiceAI] 🔇 Silence detected")
                    #endif
                    if self.sessionState == .userSpeaking {
                        self.updateState(.aiThinking)
                    }
                },
                onFinalResult: { [weak self] finalText in
                    #if DEBUG
                    dprint("[LocalVoiceAI] 📝 Final result: '\(finalText)'")
                    #endif
                    guard let self else { return }
                    let trimmed = finalText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty {
                        // Heard sound but couldn't transcribe it. Gently re-engage —
                        // never "I didn't catch that" (feels like failure). Also avoids
                        // the conversation silently hanging here.
                        #if DEBUG
                        dprint("[LocalVoiceAI] ⚠️ Empty final — gently re-engaging")
                        #endif
                        self.gentlyReEngage()
                        return
                    }
                    self.consecutiveEmptyFinals = 0
                    Task {
                        await self.processUserInput(trimmed)
                    }
                }
            )
            armIdleTimer()
        } catch {
            updateState(.error("Could not start listening: \(error.localizedDescription)"))
        }
    }

    // MARK: - Process User Input → LLM → TTS

    private func processUserInput(_ text: String) async {
        guard !isProcessing else {
            #if DEBUG
            dprint("[LocalVoiceAI] ⚠️ Already processing, skipping")
            #endif
            return
        }
        isProcessing = true
        stopRequested = false
        await MainActor.run { [weak self] in
            self?.idleTimer?.invalidate()
            self?.idleTimer = nil
            self?.idleNudgesSent = 0
        }
        #if DEBUG
        dprint("[LocalVoiceAI] 🧠 Processing user input: '\(text)'")
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
            dprint("[LocalVoiceAI] 🔄 Trimmed \(excess) old conversation turns")
            #endif
        }

        // Stream LLM response
        guard let llm = llmService else {
            #if DEBUG
            dprint("[LocalVoiceAI] ❌ llmService is nil!")
            #endif
            isProcessing = false
            return
        }

        // Trim context proactively BEFORE generation to ensure space
        llm.trimContextIfNeeded()

        // Arm the cancellation flag for a generation we know is wanted.
        // (LocalLLMService never resets it itself — see cancelGeneration docs.)
        llm.cancelGeneration = false

        tokenBuffer = ""
        isFirstSentenceSpoken = false
        var fullResponse = ""
        var tokenCount = 0
        let generationStartTime = Date()
        var receivedFirstToken = false
        var timedOut = false

        #if DEBUG
        dprint("[LocalVoiceAI] 📤 Sending to LLM: '\(text)'")
        #endif

        for await token in llm.generateResponse(userMessage: text) {
            if !receivedFirstToken {
                receivedFirstToken = true
                let latency = Date().timeIntervalSince(generationStartTime)
                #if DEBUG
                dprint("[LocalVoiceAI] ⏱️ First token latency: \(String(format: "%.2f", latency))s")
                #endif
            }

            tokenCount += 1
            fullResponse += token
            tokenBuffer += token
            #if DEBUG
            if tokenCount <= 10 {
                dprint("[LocalVoiceAI] 🔤 Token \(tokenCount): '\(token)'")
            }
            #endif

            // Detect sentence/clause boundaries for streaming TTS.
            // Break aggressively on the first chunk (8+ words at any punctuation)
            // to minimize time-to-first-speech, then use normal sentence breaks.
            let wordCount = tokenBuffer.split(separator: " ").count
            let pattern: String
            if !isFirstSentenceSpoken && wordCount >= 8 {
                // First chunk: break at any clause boundary for fastest TTS start
                pattern = #"[.!?,;:\u{2014}\-][\"'\u{201D}\u{2019}]?[\s]*"#
            } else if wordCount >= 15 {
                // Long buffer: allow clause-level breaks
                pattern = #"[.!?,;][\"'\u{201D}\u{2019}]?[\s]*"#
            } else {
                pattern = #"[.!?][\"'\u{201D}\u{2019}]?[\s]*"#
            }
            while let range = tokenBuffer.range(of: pattern, options: .regularExpression) {
                let sentence = String(tokenBuffer[tokenBuffer.startIndex..<range.upperBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                tokenBuffer = String(tokenBuffer[range.upperBound...])

                guard !sentence.isEmpty, !stopRequested else { continue }
                #if DEBUG
                dprint("[LocalVoiceAI] 💬 Sentence ready: '\(sentence)'")
                #endif

                if !isFirstSentenceSpoken {
                    isFirstSentenceSpoken = true
                    updateState(.aiSpeaking)
                    await MainActor.run { [weak self] in
                        // expectingMore: generation is still streaming — the
                        // completion callback must not fire (mic must not open)
                        // until finishStreaming() marks the reply complete.
                        SpeechService.shared.speakSentences([sentence], expectingMore: true) { [weak self] in
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
                dprint("[LocalVoiceAI] ⏰ Generation timeout after 45s")
                #endif
                timedOut = true
                llm.cancelGeneration = true
                break
            }
        }

        let totalTime = Date().timeIntervalSince(generationStartTime)
        #if DEBUG
        dprint("[LocalVoiceAI] 📊 Generation done: \(tokenCount) tokens in \(String(format: "%.1f", totalTime))s, response: '\(fullResponse.prefix(200))'")
        #endif

        // Flush remaining buffer — but not after a user stop, and not a
        // mid-sentence fragment from the 45s timeout (a reply that trails off
        // mid-clause sounds broken; better to end at the last full sentence).
        let remaining = tokenBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        let isCompleteSentence = remaining.hasSuffix(".") || remaining.hasSuffix("!") || remaining.hasSuffix("?")
        if !remaining.isEmpty && !stopRequested && (!timedOut || isCompleteSentence) {
            #if DEBUG
            dprint("[LocalVoiceAI] 💬 Flushing remaining buffer: '\(remaining)'")
            #endif
            if !isFirstSentenceSpoken {
                isFirstSentenceSpoken = true
                updateState(.aiSpeaking)
                await MainActor.run { [weak self] in
                    SpeechService.shared.speakSentences([remaining], expectingMore: true) { [weak self] in
                        self?.onAllSpeechFinished()
                    }
                }
            } else {
                await MainActor.run {
                    SpeechService.shared.enqueueSentence(remaining)
                }
            }
        }

        // Generation is complete and every sentence is enqueued — allow the
        // TTS completion callback to fire once the queue drains. (Runs on all
        // exit paths; harmless no-op when nothing was spoken.)
        await MainActor.run {
            SpeechService.shared.finishStreaming()
        }

        // If nothing was generated at all, show error and go back to listening
        if fullResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            #if DEBUG
            dprint("[LocalVoiceAI] ❌ No tokens generated! receivedFirstToken=\(receivedFirstToken)")
            #endif
            isProcessing = false
            if stopRequested {
                // User stopped the reply — stopCurrentReply() already returned
                // the session to listening; nothing more to do.
                return
            }
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
    /// Starts listening as soon as TTS begins — doesn't wait for greeting to finish.
    private func generateGreeting() async {
        guard let llm = llmService else { return }

        stopRequested = false

        // 1. INSTANT canned greeting — sound starts the moment the model is
        //    ready, covering the multi-second system-prompt prefill + greeting
        //    generation that used to be dead air under "Loading AI model…".
        //    A first-time user hears a warm voice within ~a second.
        let canned = sessionLanguage == .finnish
            ? "Hei \(userName)! Mukava olla taas kanssasi."
            : "Hello \(userName)! It's lovely to be with you."
        updateState(.aiSpeaking)
        await MainActor.run { [weak self] in
            SpeechService.shared.speakSentences([canned], expectingMore: true) { [weak self] in
                self?.greetingFinished = true
                // Only restart listening if we're not already processing user input
                if self?.isProcessing == false {
                    self?.onAllSpeechFinished()
                }
            }
        }

        // 2. Meanwhile, stream the personalised memory-invitation from the LLM
        //    into the same TTS queue, right behind the canned line.
        var memoryInvite = " Say one more short, warm sentence to open the conversation."
        if let memory = userProfile?.memories.first(where: { !$0.title.isEmpty }) {
            memoryInvite = " As a soft optional invitation, mention you were just thinking of \"\(memory.title)\" and ask if they'd like to talk about it for a moment. Do not ask them to recall any facts."
        }
        let greetingPrompt = "You have just said hello to \(userName).\(memoryInvite) One or two short spoken sentences, in \(sessionLanguage.englishName). No lists, markdown, or emoji."
        llm.cancelGeneration = false   // arm for a wanted generation

        var buffer = ""
        var full = ""
        for await token in llm.generateResponse(userMessage: greetingPrompt) {
            if stopRequested { break }
            buffer += token
            full += token
            while let range = buffer.range(of: #"[.!?][\"'\u{201D}\u{2019}]?[\s]*"#, options: .regularExpression) {
                let sentence = String(buffer[buffer.startIndex..<range.upperBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                buffer = String(buffer[range.upperBound...])
                guard !sentence.isEmpty, !stopRequested else { continue }
                await MainActor.run { SpeechService.shared.enqueueSentence(sentence) }
            }
        }
        let tail = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty && !stopRequested {
            await MainActor.run { SpeechService.shared.enqueueSentence(tail) }
        }
        await MainActor.run { SpeechService.shared.finishStreaming() }

        let fullTrimmed = full.trimmingCharacters(in: .whitespacesAndNewlines)
        if !fullTrimmed.isEmpty {
            conversationHistory.append((role: "assistant", content: fullTrimmed))
        }
        #if DEBUG
        dprint("[LocalVoiceAI] 👋 Greeting: canned + streamed '\(fullTrimmed.prefix(120))'")
        #endif
    }

    /// Called when TTS finishes all queued sentences → restart listening.
    private func onAllSpeechFinished() {
        guard sessionState != .disconnected else { return }
        updateState(.listening)
        Task { @MainActor [weak self] in
            self?.startListeningCycle()
        }
    }

    /// We heard sound but couldn't transcribe it. Re-engage warmly without making
    /// the person feel they failed. After a couple of empties (likely background
    /// noise) just re-arm silently instead of talking over an empty room.
    private func gentlyReEngage() {
        guard sessionState != .disconnected, !isProcessing else { return }
        consecutiveEmptyFinals += 1

        guard consecutiveEmptyFinals <= 1 else {
            // Repeated empties are probably ambient noise — quietly resume
            // listening instead of talking into an empty room.
            onAllSpeechFinished()
            return
        }

        let line = sessionLanguage == .finnish
            ? "Olen tässä ihan rauhassa. Ota aikaa niin paljon kuin haluat."
            : "I'm right here with you. Take all the time you need."
        updateState(.aiSpeaking)
        Task { @MainActor [weak self] in
            SpeechService.shared.speakSentences([line]) { [weak self] in
                self?.onAllSpeechFinished()
            }
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
        You are a warm, gentle companion sitting beside \(profile.name), who is older and \
        may have some memory difficulties. Your purpose is simply to keep them company and \
        help them enjoy their own memories — not to inform, test, assist, or fix anything. \
        Think of yourself as a kind friend on the sofa, unhurried and fully present.

        LANGUAGE — THIS IS CRITICAL: Always speak ONLY in \(sessionLanguage.englishName) (\(sessionLanguage.nativeName)). \
        Every single reply must be entirely in \(sessionLanguage.englishName). Some of the facts below may be \
        written in another language — that does not matter, you still reply in \(sessionLanguage.englishName). \
        Never mix languages and never switch language even if \(profile.name) does.

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
                    // Rough auto-generated hint only — may be wrong. Never state it as fact.
                    prompt += " [there is a photo of this; rough hint, may be inaccurate: \(photoDesc)]"
                }
                prompt += "\n"
            }
        }

        prompt += """

        HOW TO TALK WITH \(profile.name):
        - Keep every reply to ONE, at most TWO, short spoken sentences. One idea per sentence.
        - Be warm, calm and unhurried. Lead with feeling, not information. Reflect the emotion \
        you hear ("That sounds wonderful", "You really loved that place").
        - NEVER quiz or test. Never ask "Do you remember…?", never ask for dates, names, or facts, \
        and never correct \(profile.name). If they misremember, simply go along with their version warmly.
        - Instead of asking them to recall, SHARE a detail from their life and gently invite. \
        Prefer "what was it like" / "how was that" over "why".
          GOOD: "You and Anna married at Porvoo Cathedral, with sunflowers everywhere — it sounds beautiful."
          BAD: "Do you remember where you married Anna?" or "What year was your wedding?"
        - If \(profile.name) seems confused, repeats themselves, or contradicts the facts, do not point \
        it out. Answer again warmly as if for the first time. If they seem upset, slow down, validate \
        the feeling ("I'm right here with you"), then gently move toward a calm, happy memory.
        - It is completely fine to sit in a little silence. Never rush them.
        - Speak as a person speaks aloud: NO lists, numbers, bullet points, markdown, asterisks, or emoji. \
        Spell things out (say the time and dates in words). Keep sentences short and easy to follow by ear.
        - Use ONLY the facts above. Never invent people, dates, or events. There may be photos, but you \
        cannot truly see them — never claim what a photo shows; instead mention a photo exists and invite \
        \(profile.name)'s own recollection.
        - Speak respectfully, as to a dignified adult — never babyish, sing-song, or condescending.
        - If asked whether you are an AI, answer simply and warmly, without a long disclaimer.
        - Never give medical, legal, or financial advice; gently suggest asking a family member.
        - Reply ONLY in \(sessionLanguage.englishName) (\(sessionLanguage.nativeName)), always.
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
