import Foundation

/// On-device neural text-to-speech using sherpa-onnx running Piper VITS voices.
///
/// This replaces the robotic AVSpeechSynthesizer compact voices with genuinely
/// natural neural speech — critically, including FINNISH ("harri" voice), which
/// no other on-device neural engine offers (Kokoro, Apple Personal Voice and
/// Apple enhanced voices all lack Finnish).
///
/// Voices ship in the app bundle under Resources/TTSVoices/:
///   fi/fi_FI-harri-medium.onnx + tokens.txt   (22.05 kHz)
///   en/en_US-lessac-medium.onnx + tokens.txt  (22.05 kHz)
///   espeak-ng-data/                            (shared grapheme→phoneme data)
///
/// Synthesis is a synchronous C call run on a serial queue; callers get WAV
/// `Data` ready for the existing AVAudioPlayer sentence-queue in SpeechService.
final class NeuralTTSService: @unchecked Sendable {

    static let shared = NeuralTTSService()

    /// User preference: neural voice on by default wherever a voice exists.
    var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "neuralTTSEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "neuralTTSEnabled") }
    }

    private var tts: SherpaOnnxOfflineTtsWrapper?
    private var loadedLanguage: AppLanguage?
    private let queue = DispatchQueue(label: "ai.juntunen.storyofmylife.neuraltts", qos: .userInitiated)

    private init() {}

    // MARK: - Availability

    /// Each language uses its natively-trained voice: Finnish speaks with
    /// "harri" (trained on Finnish speech — correct pronunciation), English
    /// with "lessac". Setting this true would make the English voice read
    /// Finnish too (one voice identity, but with an English accent) — tried
    /// and rejected: native pronunciation matters more than voice consistency.
    private let unifiedVoice = false

    /// The bundled voice actually used for a conversation language.
    private func voiceLanguage(for language: AppLanguage) -> AppLanguage {
        unifiedVoice ? .english : language
    }

    /// Bundle URL of the voice model for a language, or nil if not shipped.
    private func modelURL(for language: AppLanguage) -> URL? {
        let voice = voiceLanguage(for: language)
        let name = voice == .finnish ? "fi_FI-harri-medium" : "en_US-lessac-medium"
        let dir = voice == .finnish ? "fi" : "en"
        return Bundle.main.url(forResource: name, withExtension: "onnx",
                               subdirectory: "TTSVoices/\(dir)")
    }

    private func tokensURL(for language: AppLanguage) -> URL? {
        let dir = voiceLanguage(for: language) == .finnish ? "fi" : "en"
        return Bundle.main.url(forResource: "tokens", withExtension: "txt",
                               subdirectory: "TTSVoices/\(dir)")
    }

    private var espeakDataURL: URL? {
        Bundle.main.resourceURL?.appendingPathComponent("TTSVoices/espeak-ng-data", isDirectory: true)
    }

    /// True when the neural voice can be used for this language.
    func isAvailable(for language: AppLanguage) -> Bool {
        guard isEnabled,
              let espeak = espeakDataURL,
              FileManager.default.fileExists(atPath: espeak.path),
              modelURL(for: language) != nil,
              tokensURL(for: language) != nil else { return false }
        return true
    }

    // MARK: - Engine lifecycle

    /// Loads (or switches) the engine for a language. Runs on `queue`.
    /// Cache is keyed on the resolved VOICE (with unifiedVoice both app
    /// languages map to the same model — no reload on language switch).
    private func ensureLoaded(for language: AppLanguage) throws {
        let voice = voiceLanguage(for: language)
        if loadedLanguage == voice, tts != nil { return }

        guard let model = modelURL(for: language),
              let tokens = tokensURL(for: language),
              let espeak = espeakDataURL else {
            throw NeuralTTSError.voiceNotBundled
        }

        #if DEBUG
        dprint("[NeuralTTS] 🔊 Loading \(language.englishName) voice: \(model.lastPathComponent)")
        #endif
        let vits = sherpaOnnxOfflineTtsVitsModelConfig(
            model: model.path,
            lexicon: "",
            tokens: tokens.path,
            dataDir: espeak.path
        )
        let modelConfig = sherpaOnnxOfflineTtsModelConfig(vits: vits, numThreads: 2)
        var config = sherpaOnnxOfflineTtsConfig(model: modelConfig)
        tts = SherpaOnnxOfflineTtsWrapper(config: &config)
        loadedLanguage = voice
        #if DEBUG
        dprint("[NeuralTTS] ✅ Voice ready (\(language.englishName))")
        #endif
    }

    /// Frees the engine (e.g. on memory pressure). It reloads on next use.
    func unload() {
        queue.async { [weak self] in
            self?.tts = nil
            self?.loadedLanguage = nil
        }
    }

    // MARK: - Synthesis

    /// Synthesizes one sentence to 16-bit PCM WAV data at the model's sample
    /// rate. Slightly slower speaking rate (0.9) suits the elderly audience.
    func synthesizeWAV(_ text: String, language: AppLanguage, speed: Float = 0.9) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: NeuralTTSError.engineUnavailable)
                    return
                }
                do {
                    try self.ensureLoaded(for: language)
                    guard let tts = self.tts else {
                        throw NeuralTTSError.engineUnavailable
                    }
                    let audio = tts.generate(text: text, sid: 0, speed: speed)
                    let samples = audio.samples
                    guard !samples.isEmpty else { throw NeuralTTSError.emptyAudio }
                    let wav = Self.wavData(from: samples, sampleRate: Int(audio.sampleRate))
                    continuation.resume(returning: wav)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Builds a standard 44-byte-header mono 16-bit PCM WAV from float samples.
    private static func wavData(from samples: [Float], sampleRate: Int) -> Data {
        var pcm = Data(capacity: samples.count * 2)
        for s in samples {
            let clamped = max(-1.0, min(1.0, s))
            var v = Int16(clamped * 32767.0).littleEndian
            withUnsafeBytes(of: &v) { pcm.append(contentsOf: $0) }
        }

        var header = Data()
        func append(_ s: String) { header.append(contentsOf: s.utf8) }
        func append32(_ v: UInt32) { var x = v.littleEndian; withUnsafeBytes(of: &x) { header.append(contentsOf: $0) } }
        func append16(_ v: UInt16) { var x = v.littleEndian; withUnsafeBytes(of: &x) { header.append(contentsOf: $0) } }

        let dataSize = UInt32(pcm.count)
        let byteRate = UInt32(sampleRate * 2)   // mono, 16-bit
        append("RIFF"); append32(36 + dataSize); append("WAVE")
        append("fmt "); append32(16); append16(1)          // PCM
        append16(1)                                        // mono
        append32(UInt32(sampleRate)); append32(byteRate)
        append16(2); append16(16)                          // block align, bits
        append("data"); append32(dataSize)

        return header + pcm
    }
}

// MARK: - Errors

enum NeuralTTSError: LocalizedError {
    case voiceNotBundled
    case engineUnavailable
    case emptyAudio

    var errorDescription: String? {
        switch self {
        case .voiceNotBundled:   return "Neural voice files are not bundled for this language."
        case .engineUnavailable: return "Neural TTS engine could not be loaded."
        case .emptyAudio:        return "Neural TTS produced no audio."
        }
    }
}
