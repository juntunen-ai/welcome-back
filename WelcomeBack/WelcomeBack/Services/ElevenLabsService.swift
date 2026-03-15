import Foundation
import AVFoundation

/// API client for ElevenLabs voice cloning and text-to-speech.
///
/// Supports two features:
/// 1. **Voice cloning**: Upload a ~30-second audio sample to create a cloned voice.
/// 2. **TTS synthesis**: Generate speech audio using a cloned voice.
@MainActor
final class ElevenLabsService: ObservableObject {

    static let shared = ElevenLabsService()

    // MARK: - Configuration

    private static let apiKeyKeychainKey = "elevenLabsApiKey"

    /// API key stored securely in the iOS Keychain.
    var apiKey: String {
        get { KeychainService.load(key: Self.apiKeyKeychainKey) ?? "" }
        set {
            if newValue.isEmpty {
                KeychainService.delete(key: Self.apiKeyKeychainKey)
            } else {
                KeychainService.save(key: Self.apiKeyKeychainKey, value: newValue)
            }
        }
    }

    var isConfigured: Bool { !apiKey.isEmpty }

    private let baseURL = "https://api.elevenlabs.io"
    /// Low-latency model for conversational TTS.
    private let modelId = "eleven_turbo_v2_5"

    private init() {
        // One-time migration: move API key from UserDefaults to Keychain
        if let legacyKey = UserDefaults.standard.string(forKey: Self.apiKeyKeychainKey),
           !legacyKey.isEmpty,
           KeychainService.load(key: Self.apiKeyKeychainKey) == nil {
            KeychainService.save(key: Self.apiKeyKeychainKey, value: legacyKey)
            UserDefaults.standard.removeObject(forKey: Self.apiKeyKeychainKey)
            print("[ElevenLabs] Migrated API key from UserDefaults to Keychain")
        }
    }

    // MARK: - Voice Cloning

    /// Creates a cloned voice from an audio sample.
    /// - Parameters:
    ///   - name: Display name for the voice (e.g. "Anna's Voice")
    ///   - audioData: WAV or M4A audio data (~30 seconds of speech)
    /// - Returns: The voice_id for the cloned voice.
    func cloneVoice(name: String, audioData: Data) async throws -> String {
        guard isConfigured else { throw ElevenLabsError.noApiKey }

        guard let url = URL(string: "\(baseURL)/v1/voices/add") else {
            throw ElevenLabsError.requestFailed
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        // Name field
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"name\"\r\n\r\n".utf8))
        body.append(Data("\(name)\r\n".utf8))
        // Audio file
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"files\"; filename=\"sample.m4a\"\r\n".utf8))
        body.append(Data("Content-Type: audio/mp4\r\n\r\n".utf8))
        body.append(audioData)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ElevenLabsError.requestFailed
        }
        guard httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[ElevenLabs] Clone failed (\(httpResponse.statusCode)): \(errorMsg)")
            throw ElevenLabsError.apiError(httpResponse.statusCode, errorMsg)
        }

        let json = try JSONDecoder().decode(VoiceResponse.self, from: data)
        print("[ElevenLabs] Voice cloned: id=\(json.voice_id)")
        return json.voice_id
    }

    // MARK: - Text-to-Speech

    /// Synthesizes speech from text using a cloned voice.
    /// - Parameters:
    ///   - text: The text to speak.
    ///   - voiceId: The ElevenLabs voice_id.
    /// - Returns: Audio data in MP3 format.
    func synthesize(text: String, voiceId: String) async throws -> Data {
        guard isConfigured else { throw ElevenLabsError.noApiKey }

        guard let url = URL(string: "\(baseURL)/v1/text-to-speech/\(voiceId)") else {
            throw ElevenLabsError.requestFailed
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "text": text,
            "model_id": modelId,
            "voice_settings": [
                "stability": 0.5,
                "similarity_boost": 0.75,
                "style": 0.0,
                "use_speaker_boost": true
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ElevenLabsError.apiError(statusCode, errorMsg)
        }

        return data
    }

    // MARK: - Delete Voice

    /// Deletes a cloned voice from ElevenLabs.
    func deleteVoice(voiceId: String) async throws {
        guard isConfigured else { throw ElevenLabsError.noApiKey }

        guard let url = URL(string: "\(baseURL)/v1/voices/\(voiceId)") else {
            throw ElevenLabsError.requestFailed
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ElevenLabsError.requestFailed
        }
        print("[ElevenLabs] Voice deleted: \(voiceId)")
    }

    // MARK: - Test Connection

    /// Tests the API key by fetching the user's subscription info.
    func testConnection() async throws -> Bool {
        guard isConfigured else { throw ElevenLabsError.noApiKey }

        guard let url = URL(string: "\(baseURL)/v1/user/subscription") else {
            throw ElevenLabsError.requestFailed
        }
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { return false }
        return httpResponse.statusCode == 200
    }

    // MARK: - Audio Playback Helper

    /// Plays MP3 audio data through the speaker. Returns when playback completes.
    func playAudioData(_ data: Data) async throws {
        // Set up audio session for playback
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)

        return try await withCheckedThrowingContinuation { continuation in
            let player = AudioDataPlayer(data: data) {
                continuation.resume()
            }
            player.play()
            // Keep player alive until playback completes
            objc_setAssociatedObject(self, "currentPlayer", player, .OBJC_ASSOCIATION_RETAIN)
        }
    }
}

// MARK: - Types

private struct VoiceResponse: Decodable {
    let voice_id: String
}

enum ElevenLabsError: LocalizedError {
    case noApiKey
    case requestFailed
    case apiError(Int, String)

    var errorDescription: String? {
        switch self {
        case .noApiKey: return "ElevenLabs API key not set."
        case .requestFailed: return "Request to ElevenLabs failed."
        case .apiError(let code, let msg): return "ElevenLabs error \(code): \(msg)"
        }
    }
}

// MARK: - Audio Data Player

/// Simple AVAudioPlayer wrapper that calls a completion handler when done.
private class AudioDataPlayer: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    private var completion: () -> Void

    init(data: Data, completion: @escaping () -> Void) {
        self.completion = completion
        super.init()
        do {
            player = try AVAudioPlayer(data: data)
            player?.delegate = self
        } catch {
            print("[ElevenLabs] Failed to create audio player: \(error)")
        }
    }

    func play() {
        guard let player else {
            completion()
            return
        }
        player.play()
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        completion()
    }
}
