import Foundation
import UIKit
import Vision

/// Pre-computes text descriptions of photos using the Vision framework.
/// Descriptions are cached to disk and injected into the LLM system prompt
/// so the text-only model can "see" what's in each photo.
@MainActor
final class ImageDescriptionService: ObservableObject {

    static let shared = ImageDescriptionService()

    /// Cached descriptions keyed by imageURL.
    @Published private(set) var descriptions: [String: String] = [:]

    private let cacheURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("image_descriptions.json")
    }()

    private init() {
        loadCache()
    }

    // MARK: - Public API

    /// Generates descriptions for all photos in the user profile.
    /// Skips images that already have cached descriptions.
    func generateDescriptions(for profile: UserProfile) async {
        var updated = false

        // Family member photos
        for member in profile.familyMembers {
            if !member.imageURL.isEmpty, descriptions[member.imageURL] == nil {
                if let image = PersistenceService.loadImage(imageURL: member.imageURL) {
                    let desc = await describeImage(image)
                    descriptions[member.imageURL] = desc
                    updated = true
                }
            }
            for photoURL in member.additionalPhotoURLs where !photoURL.isEmpty {
                if descriptions[photoURL] == nil {
                    if let image = PersistenceService.loadImage(imageURL: photoURL) {
                        let desc = await describeImage(image)
                        descriptions[photoURL] = desc
                        updated = true
                    }
                }
            }
        }

        // Memory photos
        for memory in profile.memories where !memory.imageURL.isEmpty {
            if descriptions[memory.imageURL] == nil {
                if let image = PersistenceService.loadImage(imageURL: memory.imageURL) {
                    let desc = await describeImage(image)
                    descriptions[memory.imageURL] = desc
                    updated = true
                }
            }
        }

        if updated {
            saveCache()
            print("[ImageDesc] Generated \(descriptions.count) total descriptions")
        }
    }

    /// Returns the cached description for an imageURL, or nil.
    func description(for imageURL: String) -> String? {
        descriptions[imageURL]
    }

    // MARK: - Vision Analysis

    /// Combines scene classification + text recognition into a single description string.
    private nonisolated func describeImage(_ image: UIImage) async -> String {
        guard let cgImage = image.cgImage else { return "photo" }

        var parts: [String] = []

        // Scene classification
        let sceneTags = await classifyScene(cgImage)
        if !sceneTags.isEmpty {
            parts.append(sceneTags.joined(separator: ", "))
        }

        // Text recognition (any text visible in the photo)
        let texts = await recognizeText(cgImage)
        if !texts.isEmpty {
            parts.append("text visible: \(texts.joined(separator: "; "))")
        }

        // Face count
        let faceCount = await detectFaceCount(cgImage)
        if faceCount > 0 {
            parts.append("\(faceCount) \(faceCount == 1 ? "person" : "people") visible")
        }

        return parts.isEmpty ? "photo" : parts.joined(separator: "; ")
    }

    /// Uses VNClassifyImageRequest to get scene classification tags.
    private nonisolated func classifyScene(_ cgImage: CGImage) async -> [String] {
        await withCheckedContinuation { continuation in
            let request = VNClassifyImageRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
                let results = (request.results as? [VNClassificationObservation]) ?? []
                let tags = results
                    .filter { $0.confidence > 0.3 }
                    .prefix(3)
                    .map { $0.identifier.replacingOccurrences(of: "_", with: " ") }
                continuation.resume(returning: Array(tags))
            } catch {
                continuation.resume(returning: [])
            }
        }
    }

    /// Uses VNRecognizeTextRequest to find any text in the photo.
    private nonisolated func recognizeText(_ cgImage: CGImage) async -> [String] {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .fast
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
                let results = (request.results as? [VNRecognizedTextObservation]) ?? []
                let texts = results.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: Array(texts.prefix(3)))
            } catch {
                continuation.resume(returning: [])
            }
        }
    }

    /// Counts faces in the image.
    private nonisolated func detectFaceCount(_ cgImage: CGImage) async -> Int {
        await withCheckedContinuation { continuation in
            let request = VNDetectFaceRectanglesRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
                let count = (request.results as? [VNFaceObservation])?.count ?? 0
                continuation.resume(returning: count)
            } catch {
                continuation.resume(returning: 0)
            }
        }
    }

    // MARK: - Cache Persistence

    private func loadCache() {
        guard FileManager.default.fileExists(atPath: cacheURL.path) else { return }
        do {
            let data = try Data(contentsOf: cacheURL)
            descriptions = try JSONDecoder().decode([String: String].self, from: data)
            print("[ImageDesc] Loaded \(descriptions.count) cached descriptions")
        } catch {
            print("[ImageDesc] Failed to load cache: \(error)")
        }
    }

    private func saveCache() {
        do {
            let data = try JSONEncoder().encode(descriptions)
            try data.write(to: cacheURL, options: [.atomic, .completeFileProtection])
        } catch {
            print("[ImageDesc] Failed to save cache: \(error)")
        }
    }
}
