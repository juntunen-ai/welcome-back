import Foundation
import AVFoundation

/// API client for the local F5-TTS voice cloning server.
///
/// Connects to a self-hosted F5-TTS server on the home network for:
/// 1. **Voice reference management**: Upload/list/delete voice samples.
/// 2. **TTS synthesis**: Generate speech audio using a cloned voice.
///
/// Falls back gracefully when the server is unreachable — callers should
/// check `isConfigured` before attempting synthesis.
@MainActor
final class F5TTSService: ObservableObject {

    static let shared = F5TTSService()

    // MARK: - Configuration

    private static let serverURLKey = "f5ttsServerURL"

    /// Server URL stored in UserDefaults (e.g. "http://192.168.1.50:5005").
    var serverURL: String {
        get { UserDefaults.standard.string(forKey: Self.serverURLKey) ?? "" }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.serverURLKey)
            objectWillChange.send()
        }
    }

    var isConfigured: Bool { !serverURL.isEmpty }

    /// Base URL with trailing slashes and whitespace stripped.
    private var cleanBaseURL: String {
        serverURL.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.init(charactersIn: "/")))
    }

    /// URLSession with short timeouts for LAN communication.
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    private init() {}

    // MARK: - Health Check

    /// Tests connectivity to the F5-TTS server.
    func testConnection() async throws -> Bool {
        guard isConfigured else {
            print("[F5-TTS] Test failed: no server URL configured")
            throw F5TTSError.noServerURL
        }

        guard let url = URL(string: "\(cleanBaseURL)/v1/health") else {
            print("[F5-TTS] Test failed: invalid URL '\(serverURL)'")
            throw F5TTSError.serverUnreachable
        }

        print("[F5-TTS] Testing connection to \(url.absoluteString)...")

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            print("[F5-TTS] Test failed: no HTTP response")
            return false
        }

        print("[F5-TTS] Server responded with status \(http.statusCode)")

        guard http.statusCode == 200 else { return false }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let status = json["status"] as? String {
            print("[F5-TTS] Health check: status=\(status)")
            return status == "ok"
        }
        return false
    }

    // MARK: - Voice References

    /// Uploads a voice reference audio sample to the server.
    /// - Parameters:
    ///   - name: Display name (e.g. "Anna's Voice")
    ///   - audioData: WAV audio data (~10-30 seconds of speech)
    /// - Returns: The reference_id for the stored voice.
    func uploadReference(name: String, audioData: Data) async throws -> String {
        guard isConfigured else { throw F5TTSError.noServerURL }

        guard let url = URL(string: "\(cleanBaseURL)/v1/references") else {
            throw F5TTSError.requestFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        // Name field
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"name\"\r\n\r\n".utf8))
        body.append(Data("\(name)\r\n".utf8))
        // Audio file
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"audio\"; filename=\"sample.wav\"\r\n".utf8))
        body.append(Data("Content-Type: audio/wav\r\n\r\n".utf8))
        body.append(audioData)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))

        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw F5TTSError.apiError(statusCode, errorMsg)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let refId = json["reference_id"] as? String else {
            throw F5TTSError.requestFailed
        }

        print("[F5-TTS] Voice reference uploaded: \(name) (\(refId))")
        return refId
    }

    /// Lists all stored voice references on the server.
    func listReferences() async throws -> [VoiceReference] {
        guard isConfigured else { throw F5TTSError.noServerURL }

        guard let url = URL(string: "\(cleanBaseURL)/v1/references") else {
            throw F5TTSError.requestFailed
        }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw F5TTSError.requestFailed
        }

        guard let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        return array.compactMap { item in
            guard let id = item["reference_id"] as? String,
                  let name = item["name"] as? String else { return nil }
            return VoiceReference(id: id, name: name)
        }
    }

    /// Deletes a voice reference from the server.
    func deleteReference(id: String) async throws {
        guard isConfigured else { throw F5TTSError.noServerURL }

        guard let url = URL(string: "\(cleanBaseURL)/v1/references/\(id)") else {
            throw F5TTSError.requestFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw F5TTSError.requestFailed
        }
        print("[F5-TTS] Voice reference deleted: \(id)")
    }

    // MARK: - Text-to-Speech

    /// Synthesizes speech from text using a cloned voice.
    /// - Parameters:
    ///   - text: The text to speak.
    ///   - referenceId: The server-side reference_id for the cloned voice.
    /// - Returns: Audio data in WAV format.
    func synthesize(text: String, referenceId: String) async throws -> Data {
        guard isConfigured else { throw F5TTSError.noServerURL }

        guard let url = URL(string: "\(cleanBaseURL)/v1/tts") else {
            throw F5TTSError.requestFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "text": text,
            "reference_id": referenceId
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw F5TTSError.apiError(statusCode, errorMsg)
        }

        return data
    }

    // MARK: - Audio Playback Helper

    /// Plays WAV audio data through the speaker. Returns when playback completes.
    func playAudioData(_ data: Data) async throws {
        let avSession = AVAudioSession.sharedInstance()
        try avSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try avSession.setActive(true)

        return try await withCheckedThrowingContinuation { continuation in
            let player = AudioDataPlayer(data: data) {
                continuation.resume()
            }
            player.play()
            objc_setAssociatedObject(self, "currentPlayer", player, .OBJC_ASSOCIATION_RETAIN)
        }
    }
}

// MARK: - Types

struct VoiceReference: Identifiable {
    let id: String
    let name: String
}

enum F5TTSError: LocalizedError {
    case noServerURL
    case serverUnreachable
    case requestFailed
    case apiError(Int, String)

    var errorDescription: String? {
        switch self {
        case .noServerURL:           return "Voice cloning server URL not set."
        case .serverUnreachable:     return "Cannot reach the voice cloning server."
        case .requestFailed:         return "Request to voice cloning server failed."
        case .apiError(let code, let msg): return "Server error \(code): \(msg)"
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
            print("[F5-TTS] Failed to create audio player: \(error)")
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
