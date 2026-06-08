import Foundation
import AVFoundation
import Speech
import Accelerate

/// Handles speech recognition (STT) and text-to-speech (TTS).
@MainActor
final class SpeechService: NSObject, ObservableObject {

    static let shared = SpeechService()

    // MARK: - Published State

    @Published var isListening = false
    @Published var transcribedText = ""
    @Published var isSpeaking = false

    // MARK: - Private

    /// Speech recognizer for the current app language. Recreated at the start of
    /// each listening session so STT matches the conversation language (e.g. fi-FI
    /// when the app/content is Finnish). Built via `makeRecognizer()`.
    private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: LanguageManager.shared.language.speechLocaleIdentifier))

    /// Creates a recognizer for the current app language.
    private func makeRecognizer() -> SFSpeechRecognizer? {
        SFSpeechRecognizer(locale: Locale(identifier: LanguageManager.shared.language.speechLocaleIdentifier))
    }

    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let synthesizer = AVSpeechSynthesizer()

    // VAD state
    private var lastSpeechTime: Date = .distantPast
    private var isSpeechActive = false
    private var silenceThreshold: TimeInterval = 1.5
    private var silenceTimer: Timer?
    private var vadSilenceCallback: (() -> Void)?
    private var vadFinalCallback: ((String) -> Void)?

    // Adaptive VAD: noise floor calibration
    private var noiseFloorDb: Float = -40   // initial conservative estimate
    private var noiseCalibrationSamples: [Float] = []
    private var isCalibrating = true
    private let calibrationSampleCount = 8   // ~512ms at 64ms/buffer — faster start
    private let speechMarginDb: Float = 10   // speech must be this much louder than noise

    // Sentence TTS queue (AVSpeechSynthesizer path)
    private var pendingUtteranceCount = 0
    private var allFinishedCallback: (() -> Void)?

    // Cloned voice WAV queue (F5-TTS path)
    private var wavPlayer: AVAudioPlayer?
    private var wavQueue: [String] = []        // sentences waiting to be synthesized + played
    private var wavVoiceProfileID: String?      // current voice profile for WAV queue
    private var isWavPlaying = false

    /// The voice identifier to use for TTS. If set, uses this voice instead of default.
    /// Can be a Personal Voice identifier or a premium Apple voice.
    var selectedVoiceIdentifier: String? {
        get { UserDefaults.standard.string(forKey: "selectedVoiceIdentifier") }
        set { UserDefaults.standard.set(newValue, forKey: "selectedVoiceIdentifier") }
    }

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Audio Session

    /// Configures the audio session for the given mode.
    /// Centralised to avoid category thrashing between STT and TTS.
    private func configureAudioSession(forListening: Bool) throws {
        let session = AVAudioSession.sharedInstance()
        if forListening {
            try session.setCategory(.playAndRecord, mode: .measurement,
                                     options: [.defaultToSpeaker, .allowBluetoothA2DP])
        } else {
            try session.setCategory(.playAndRecord, mode: .default,
                                     options: [.defaultToSpeaker, .allowBluetoothA2DP])
        }
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Personal Voice

    /// Requests authorization to use Personal Voice.
    func requestPersonalVoiceAccess() async -> Bool {
        let status = await AVSpeechSynthesizer.requestPersonalVoiceAuthorization()
        return status == .authorized
    }

    /// Returns available Personal Voices (requires prior authorization).
    func availablePersonalVoices() -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices().filter { $0.voiceTraits.contains(.isPersonalVoice) }
    }

    /// Returns the current Personal Voice authorization status.
    var personalVoiceAuthStatus: AVSpeechSynthesizer.PersonalVoiceAuthorizationStatus {
        AVSpeechSynthesizer.personalVoiceAuthorizationStatus
    }

    // MARK: - Speech Recognition (Original)

    func requestSpeechPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func startListening() throws {
        guard !isListening else { return }

        transcribedText = ""
        speechRecognizer = makeRecognizer()   // match current app language

        try configureAudioSession(forListening: true)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }
        request.shouldReportPartialResults = true

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                Task { @MainActor in
                    self.transcribedText = result.bestTranscription.formattedString
                }
            }
        }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isListening = true
    }

    func stopListening() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        vadSilenceCallback = nil
        vadFinalCallback = nil
        isSpeechActive = false

        guard audioEngine.isRunning else {
            recognitionRequest = nil
            recognitionTask?.cancel()
            recognitionTask = nil
            isListening = false
            return
        }

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false

        // Deactivate audio session so TTS can reconfigure it cleanly
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Speech Recognition with VAD (for Local Voice AI)

    /// Starts listening with voice activity detection for end-of-speech.
    ///
    /// - Parameters:
    ///   - silenceThreshold: Seconds of silence before speech is considered finished (default 1.5s)
    ///   - onPartialResult: Called with streaming partial transcription as the user speaks
    ///   - onSilenceDetected: Called once when silence exceeds threshold
    ///   - onFinalResult: Called with the best transcription after silence is detected
    func startListeningWithVAD(
        silenceThreshold: TimeInterval = 1.5,
        onPartialResult: @escaping (String) -> Void,
        onSilenceDetected: @escaping () -> Void,
        onFinalResult: @escaping (String) -> Void
    ) throws {
        guard !isListening else { return }

        self.silenceThreshold = silenceThreshold
        self.vadSilenceCallback = onSilenceDetected
        self.vadFinalCallback = onFinalResult
        self.isSpeechActive = false
        self.lastSpeechTime = .distantPast
        self.noiseCalibrationSamples = []
        self.isCalibrating = true
        self.noiseFloorDb = -40
        transcribedText = ""
        speechRecognizer = makeRecognizer()   // match current app language

        try configureAudioSession(forListening: true)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }
        request.shouldReportPartialResults = true

        // Prefer on-device recognition for offline use
        if speechRecognizer?.supportsOnDeviceRecognition == true {
            request.requiresOnDeviceRecognition = true
        }

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let text = result.bestTranscription.formattedString
                Task { @MainActor in
                    self.transcribedText = text
                    onPartialResult(text)
                }
            }
        }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            // Feed audio to speech recognizer
            self.recognitionRequest?.append(buffer)

            // VAD: compute RMS amplitude
            self.processAudioBufferForVAD(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isListening = true

        // Periodically check for silence
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkSilence()
            }
        }
    }

    /// Computes RMS amplitude from audio buffer for voice activity detection.
    /// Uses adaptive noise floor calibration from the first ~1s of audio.
    private nonisolated func processAudioBufferForVAD(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = UInt(buffer.frameLength)
        guard frameLength > 0 else { return }

        var rms: Float = 0
        vDSP_measqv(channelData, 1, &rms, vDSP_Length(frameLength))
        rms = sqrtf(rms)

        let dbLevel = 20 * log10f(max(rms, 1e-10))

        Task { @MainActor [weak self] in
            guard let self else { return }

            if self.isCalibrating {
                // Collect noise floor samples from the first ~1s
                self.noiseCalibrationSamples.append(dbLevel)
                if self.noiseCalibrationSamples.count >= self.calibrationSampleCount {
                    // Use median of samples as noise floor (robust to outliers)
                    let sorted = self.noiseCalibrationSamples.sorted()
                    let median = sorted[sorted.count / 2]
                    // Clamp noise floor to reasonable range
                    self.noiseFloorDb = max(-55, min(-20, median))
                    self.isCalibrating = false
                    #if DEBUG
                    dprint("[SpeechService] 🎤 Noise floor calibrated: \(String(format: "%.1f", self.noiseFloorDb)) dB, threshold: \(String(format: "%.1f", self.noiseFloorDb + self.speechMarginDb)) dB")
                    #endif
                }
                return
            }

            // Adaptive threshold: speech must be speechMarginDb above noise floor
            let threshold = self.noiseFloorDb + self.speechMarginDb
            if dbLevel > threshold {
                self.lastSpeechTime = Date()
                self.isSpeechActive = true
            }
        }
    }

    /// Checks if silence duration exceeds the threshold.
    private func checkSilence() {
        guard isSpeechActive else { return }
        let elapsed = Date().timeIntervalSince(lastSpeechTime)

        if elapsed > silenceThreshold {
            isSpeechActive = false

            // Capture the final transcription and callbacks BEFORE stopListening()
            // because stopListening() nils out the callbacks
            let finalText = transcribedText
            let silenceCallback = vadSilenceCallback
            let finalCallback = vadFinalCallback

            // Notify silence detected
            silenceCallback?()

            // Stop listening (this clears vadSilenceCallback & vadFinalCallback)
            stopListening()

            // Deliver final result AFTER stopping
            #if DEBUG
            dprint("[SpeechService] 📝 Delivering final VAD result: '\(finalText)'")
            #endif
            finalCallback?(finalText)
        }
    }

    // MARK: - Text-to-Speech (Single)

    /// Speaks text, using F5-TTS cloned voice if `voiceProfileID` is provided and server is configured.
    func speak(_ text: String, voiceIdentifier: String? = nil, voiceProfileID: String? = nil) {
        if let profileID = voiceProfileID, F5TTSService.shared.isConfigured {
            speakWithClonedVoice(text, referenceId: profileID)
            return
        }

        let utterance = makeUtterance(text, voiceIdentifier: voiceIdentifier)
        synthesizer.speak(utterance)
        isSpeaking = true
    }

    /// Synthesizes and plays text using a cloned voice from the F5-TTS server.
    private func speakWithClonedVoice(_ text: String, referenceId: String) {
        isSpeaking = true
        Task {
            do {
                let wavData = try await F5TTSService.shared.synthesize(text: text, referenceId: referenceId)
                try await F5TTSService.shared.playAudioData(wavData)
            } catch {
                #if DEBUG
                dprint("[SpeechService] F5-TTS failed, falling back to Apple voice: \(error.localizedDescription)")
                #endif
                speak(text)
                return
            }
            isSpeaking = false
        }
    }

    // MARK: - Text-to-Speech (Sentence Queue — for streaming LLM output)

    /// Speaks the first batch of sentences, calling `onAllFinished` when every
    /// utterance (including subsequently enqueued ones) has completed.
    /// When `voiceProfileID` is provided and F5-TTS is configured, uses cloned voice.
    func speakSentences(_ sentences: [String],
                        voiceIdentifier: String? = nil,
                        voiceProfileID: String? = nil,
                        onAllFinished: @escaping () -> Void) {
        try? configureAudioSession(forListening: false)
        allFinishedCallback = onAllFinished

        // F5-TTS cloned voice path
        if let profileID = voiceProfileID, F5TTSService.shared.isConfigured {
            wavVoiceProfileID = profileID
            wavQueue = sentences
            isSpeaking = true
            playNextWavSentence()
            return
        }

        // Apple voice path
        pendingUtteranceCount = sentences.count
        for sentence in sentences {
            synthesizer.speak(makeUtterance(sentence, voiceIdentifier: voiceIdentifier))
        }
        isSpeaking = true
    }

    /// Enqueues an additional sentence while speaking.
    /// When `voiceProfileID` is provided and F5-TTS is configured, uses cloned voice.
    func enqueueSentence(_ sentence: String, voiceIdentifier: String? = nil, voiceProfileID: String? = nil) {
        // F5-TTS path: add to WAV queue
        if let profileID = voiceProfileID, F5TTSService.shared.isConfigured {
            wavVoiceProfileID = profileID
            wavQueue.append(sentence)
            if !isWavPlaying { playNextWavSentence() }
            return
        }

        // Apple voice path
        pendingUtteranceCount += 1
        synthesizer.speak(makeUtterance(sentence, voiceIdentifier: voiceIdentifier))
    }

    // MARK: - WAV Queue Playback (F5-TTS)

    /// Plays the next sentence in the WAV queue via F5-TTS synthesis.
    private func playNextWavSentence() {
        guard !wavQueue.isEmpty, let profileID = wavVoiceProfileID else {
            // Queue exhausted
            isWavPlaying = false
            isSpeaking = false
            allFinishedCallback?()
            allFinishedCallback = nil
            return
        }

        let sentence = wavQueue.removeFirst()
        isWavPlaying = true

        Task {
            do {
                let wavData = try await F5TTSService.shared.synthesize(text: sentence, referenceId: profileID)
                let player = try AVAudioPlayer(data: wavData)
                self.wavPlayer = player
                player.delegate = self
                player.play()
            } catch {
                // Fallback: speak this sentence with Apple voice, then continue queue
                #if DEBUG
                dprint("[SpeechService] F5-TTS sentence failed, using Apple voice: \(error.localizedDescription)")
                #endif
                // After this utterance finishes, the delegate will call playNextWavSentence
                pendingUtteranceCount = 1
                synthesizer.speak(makeUtterance(sentence, voiceIdentifier: nil))
            }
        }
    }

    /// Resolves the voice to use: explicit param > selectedVoiceIdentifier > the
    /// highest-quality voice available for the current app language.
    /// A language-matched voice is essential: an English voice pronouncing Finnish
    /// text sounds like garbled nonsense. For English, prefer enhanced/premium
    /// voices (far less robotic) if the user has downloaded any; Finnish only ships
    /// the compact "Satu" voice, so this gracefully returns that.
    private func resolveVoice(explicit voiceIdentifier: String?) -> AVSpeechSynthesisVoice? {
        if let voiceID = voiceIdentifier ?? selectedVoiceIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: voiceID) {
            return voice
        }
        return bestVoice(forBCP47: LanguageManager.shared.language.speechLocaleIdentifier)
    }

    /// Returns the best-quality installed voice for a BCP-47 identifier (e.g. "en-US"),
    /// preferring .premium > .enhanced > .default. Falls back to the language default.
    private func bestVoice(forBCP47 id: String) -> AVSpeechSynthesisVoice? {
        let prefix = String(id.prefix(2))   // "en", "fi"
        let candidates = AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language.hasPrefix(prefix)
        }
        if let best = candidates.max(by: { $0.quality.rawValue < $1.quality.rawValue }) {
            return best
        }
        // Last resort: ask for the exact language (may be nil if the user removed it).
        return AVSpeechSynthesisVoice(language: id)
    }

    // MARK: - Speech Text Sanitization & Utterance Factory

    /// Calmer speaking rate for an elderly / memory-support audience.
    /// Caregiver-tunable via UserDefaults; defaults to a gentle pace below Apple's ~0.5 default.
    var speechRate: Float {
        get {
            let v = UserDefaults.standard.float(forKey: "speechRate")
            return v > 0 ? v : 0.46
        }
        set { UserDefaults.standard.set(newValue, forKey: "speechRate") }
    }

    /// Small pause between sentences so streamed multi-sentence output doesn't feel rushed.
    private let interSentencePause: TimeInterval = 0.2

    /// Strips markdown, list markers, stray symbols and emoji so the synthesizer
    /// never voices "asterisk asterisk", "number sign", or spells out emoji.
    /// Preserves sentence-ending punctuation (. ! ? , ; :) — the streaming splitter
    /// in LocalVoiceAIService depends on it.
    func sanitizeForSpeech(_ text: String) -> String {
        var s = text
        // Markdown emphasis / code / headings
        s = s.replacingOccurrences(of: #"[*_`#>]"#, with: "", options: .regularExpression)
        // Leading list bullets ("- ", "* ", "• ", "1. ") at the start of lines
        s = s.replacingOccurrences(of: #"(?m)^\s*([-*•]|\d+\.)\s+"#, with: "", options: .regularExpression)
        // Markdown links [text](url) -> text
        s = s.replacingOccurrences(of: #"\[([^\]]+)\]\([^)]+\)"#, with: "$1", options: .regularExpression)
        // Bare URLs
        s = s.replacingOccurrences(of: #"https?://\S+"#, with: "", options: .regularExpression)
        // Emoji / symbol scalars
        s = String(s.unicodeScalars.filter { !$0.properties.isEmoji || ($0.value >= 0x30 && $0.value <= 0x39) })
        // Collapse whitespace
        s = s.replacingOccurrences(of: #"[ \t]{2,}"#, with: " ", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Builds a sanitized, gently-paced utterance with the resolved voice.
    private func makeUtterance(_ text: String, voiceIdentifier: String?) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: sanitizeForSpeech(text))
        utterance.rate = speechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        utterance.postUtteranceDelay = interSentencePause
        utterance.voice = resolveVoice(explicit: voiceIdentifier)
        return utterance
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        wavPlayer?.stop()
        wavPlayer = nil
        wavQueue.removeAll()
        isWavPlaying = false
        isSpeaking = false
        pendingUtteranceCount = 0
        allFinishedCallback = nil
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension SpeechService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.pendingUtteranceCount -= 1
            if self.pendingUtteranceCount <= 0 {
                self.pendingUtteranceCount = 0
                // If we're in WAV queue mode (fallback utterance finished), continue the queue
                if !self.wavQueue.isEmpty {
                    self.playNextWavSentence()
                } else if !self.isWavPlaying {
                    self.isSpeaking = false
                    self.allFinishedCallback?()
                    self.allFinishedCallback = nil
                }
            }
        }
    }
}

// MARK: - AVAudioPlayerDelegate (WAV playback)

extension SpeechService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.wavPlayer = nil
            self.playNextWavSentence()
        }
    }
}
