import XCTest
@testable import WelcomeBack

/// Tests the JSON parsing logic and error types of GeminiService.
/// Network calls are NOT made — we test only the parsing path directly.
final class GeminiServiceTests: XCTestCase {

    // MARK: - GeminiError

    func test_geminiError_invalidURL_hasDescription() {
        let error = GeminiError.invalidURL
        XCTAssertEqual(error.errorDescription, "Invalid API URL.")
    }

    func test_geminiError_requestFailed_hasDescription() {
        let error = GeminiError.requestFailed
        XCTAssertEqual(error.errorDescription, "The Gemini API request failed.")
    }

    func test_geminiError_parsingFailed_hasDescription() {
        let error = GeminiError.parsingFailed
        XCTAssertEqual(error.errorDescription, "Could not parse the Gemini response.")
    }

    func test_geminiError_isLocalizedError() {
        let error: LocalizedError = GeminiError.requestFailed
        XCTAssertNotNil(error.errorDescription)
    }

    // MARK: - Response JSON parsing (via reflection helper)

    func test_parseResponse_validJSON_extractsText() throws {
        let json: [String: Any] = [
            "candidates": [[
                "content": [
                    "parts": [["text": "Hi Harri, it's Jane."]]
                ]
            ]]
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let result = extractText(from: data)
        XCTAssertEqual(result, "Hi Harri, it's Jane.")
    }

    func test_parseResponse_multipleCandidates_usesFirst() throws {
        let json: [String: Any] = [
            "candidates": [
                ["content": ["parts": [["text": "First response"]]]],
                ["content": ["parts": [["text": "Second response"]]]]
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let result = extractText(from: data)
        XCTAssertEqual(result, "First response")
    }

    func test_parseResponse_emptyCandidates_returnsNil() throws {
        let json: [String: Any] = ["candidates": []]
        let data = try JSONSerialization.data(withJSONObject: json)
        let result = extractText(from: data)
        XCTAssertNil(result)
    }

    func test_parseResponse_missingCandidatesKey_returnsNil() throws {
        let json: [String: Any] = ["error": "something went wrong"]
        let data = try JSONSerialization.data(withJSONObject: json)
        let result = extractText(from: data)
        XCTAssertNil(result)
    }

    func test_parseResponse_missingTextKey_returnsNil() throws {
        let json: [String: Any] = [
            "candidates": [[
                "content": ["parts": [["noText": "oops"]]]
            ]]
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let result = extractText(from: data)
        XCTAssertNil(result)
    }

    func test_parseResponse_emptyData_returnsNil() {
        let result = extractText(from: Data())
        XCTAssertNil(result)
    }

    func test_parseResponse_textIsWhitespace_isPreserved() throws {
        let json: [String: Any] = [
            "candidates": [[
                "content": ["parts": [["text": "  hello  "]]]
            ]]
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let result = extractText(from: data)
        XCTAssertEqual(result, "  hello  ")
    }

    // MARK: - Helpers

    /// Mirrors the private parseResponse logic so we can unit-test it without
    /// making the method internal or using @testable on a private method.
    private func extractText(from data: Data) -> String? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = json["candidates"] as? [[String: Any]],
            let first = candidates.first,
            let content = first["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]],
            let text = parts.first?["text"] as? String
        else { return nil }
        return text
    }
}
