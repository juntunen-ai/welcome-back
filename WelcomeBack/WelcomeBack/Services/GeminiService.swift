import Foundation

/// Communicates with the Gemini API to generate personalised memory stories.
/// Replace the placeholder implementation with the actual Google GenAI SDK
/// once it is available for Swift / added via Swift Package Manager.
actor GeminiService {

    static let shared = GeminiService()

    private let apiKey: String

    private init() {
        // Store your Gemini API key in Info.plist under "GEMINI_API_KEY"
        // or inject it via an environment / secrets manager.
        self.apiKey = Bundle.main.infoDictionary?["GEMINI_API_KEY"] as? String ?? ""
    }

    // MARK: - Public API

    /// Generates a short, warm memory story spoken "by" a family member.
    func generateMemoryStory(
        userName: String,
        familyMember: FamilyMember
    ) async throws -> String {
        guard !apiKey.isEmpty else {
            return fallbackStory(userName: userName, member: familyMember)
        }

        let prompt = """
        You are \(familyMember.name), the \(familyMember.relationship) of \(userName).
        \(userName) is struggling with memory.
        Speak directly to them as \(familyMember.name).
        Remind them of who they are and how much they are loved in a short, warm,
        and comforting paragraph (3–4 sentences).
        """

        let requestBody: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": [
                "temperature": 0.7,
                "topP": 0.8,
                "maxOutputTokens": 200
            ]
        ]

        let model = "gemini-2.0-flash"
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"

        guard let url = URL(string: urlString) else {
            throw GeminiError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw GeminiError.requestFailed
        }

        return try parseResponse(data: data, userName: userName, member: familyMember)
    }

    // MARK: - Private Helpers

    private func parseResponse(data: Data, userName: String, member: FamilyMember) throws -> String {
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = json["candidates"] as? [[String: Any]],
            let first = candidates.first,
            let content = first["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]],
            let text = parts.first?["text"] as? String
        else {
            return fallbackStory(userName: userName, member: member)
        }
        return text
    }

    private func fallbackStory(userName: String, member: FamilyMember) -> String {
        "Hi \(userName), it's \(member.name). We are all thinking of you today and love you very much."
    }
}

// MARK: - Errors

enum GeminiError: LocalizedError {
    case invalidURL
    case requestFailed
    case parsingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:     return "Invalid API URL."
        case .requestFailed:  return "The Gemini API request failed."
        case .parsingFailed:  return "Could not parse the Gemini response."
        }
    }
}
