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

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
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

    // Sentence TTS queue
    private var pendingUtteranceCount = 0
    private var allFinishedCallback: (() -> Void)?

    private override init() {
        super.init()
        synthesizer.delegate = self
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

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

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
        transcribedText = ""

        // Use playAndRecord so TTS can play after STT finishes
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement,
                                     options: [.defaultToSpeaker, .allowBluetoothA2DP])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

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
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkSilence()
            }
        }
    }

    /// Computes RMS amplitude from audio buffer for voice activity detection.
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
            if dbLevel > -40 {
                // Speech detected
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
            print("[SpeechService] 📝 Delivering final VAD result: '\(finalText)'")
            finalCallback?(finalText)
        }
    }

    // MARK: - Text-to-Speech (Single)

    func speak(_ text: String, voiceIdentifier: String? = nil) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.48
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        if let voiceID = voiceIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: voiceID) {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }

        synthesizer.speak(utterance)
        isSpeaking = true
    }

    // MARK: - Text-to-Speech (Sentence Queue — for streaming LLM output)

    /// Speaks the first batch of sentences, calling `onAllFinished` when every
    /// utterance (including subsequently enqueued ones) has completed.
    func speakSentences(_ sentences: [String],
                        voiceIdentifier: String? = nil,
                        onAllFinished: @escaping () -> Void) {
        // Set up playAndRecord so speaker works
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playAndRecord, mode: .default,
                                      options: [.defaultToSpeaker, .allowBluetoothA2DP])
        try? audioSession.setActive(true)

        pendingUtteranceCount = sentences.count
        allFinishedCallback = onAllFinished

        for sentence in sentences {
            let utterance = AVSpeechUtterance(string: sentence)
            utterance.rate = 0.48
            utterance.pitchMultiplier = 1.0
            utterance.volume = 1.0
            if let voiceID = voiceIdentifier,
               let voice = AVSpeechSynthesisVoice(identifier: voiceID) {
                utterance.voice = voice
            } else {
                utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            }
            synthesizer.speak(utterance)
        }
        isSpeaking = true
    }

    /// Enqueues an additional sentence while the synthesizer is already speaking.
    func enqueueSentence(_ sentence: String, voiceIdentifier: String? = nil) {
        pendingUtteranceCount += 1
        let utterance = AVSpeechUtterance(string: sentence)
        utterance.rate = 0.48
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        if let voiceID = voiceIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: voiceID) {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        synthesizer.speak(utterance)
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
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
                self.isSpeaking = false
                self.pendingUtteranceCount = 0
                self.allFinishedCallback?()
                self.allFinishedCallback = nil
            }
        }
    }
}
