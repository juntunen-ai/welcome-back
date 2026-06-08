import Foundation
import UIKit

/// Handles all on-disk persistence for Story of My Life.
///
/// Strategy:
///  - `UserProfile` is encoded as JSON to `Documents/userProfile.json`
///  - Family member photos are stored as JPEG files under `Documents/Photos/`
///    using the member's UUID as the filename (e.g. `abc123.jpg`)
///  - `FamilyMember.imageURL` stores either:
///      • a bare filename like `"family_jane"` → loaded from the asset catalog
///      • a path prefixed with `"photo:"` like `"photo:abc123.jpg"` → loaded from Documents
///
enum PersistenceService {

    // MARK: - Paths

    private static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private static var profileURL: URL {
        documentsURL.appendingPathComponent("userProfile.json")
    }

    private static var photosDirectoryURL: URL {
        documentsURL.appendingPathComponent("Photos", isDirectory: true)
    }

    // MARK: - Profile

    static func save(_ profile: UserProfile) {
        do {
            let data = try JSONEncoder().encode(profile)
            try data.write(to: profileURL, options: [.atomic, .completeFileProtection])
        } catch {
            #if DEBUG
            dprint("[Persistence] Save failed: \(error)")
            #endif
        }
    }

    static func load() -> UserProfile? {
        guard FileManager.default.fileExists(atPath: profileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: profileURL)
            return try JSONDecoder().decode(UserProfile.self, from: data)
        } catch {
            #if DEBUG
            dprint("[Persistence] Load failed: \(error)")
            #endif
            return nil
        }
    }

    // MARK: - Photos

    /// Saves JPEG data for a family member photo and returns the `imageURL`
    /// string to store on the `FamilyMember` (prefixed with `"photo:"`).
    /// Note: re-encodes through UIImage, which strips EXIF metadata.
    /// Prefer `savePhotoData(_:memberID:)` when the original picker Data is available.
    @discardableResult
    static func savePhoto(_ image: UIImage, memberID: String) -> String {
        createPhotosDirectoryIfNeeded()
        let filename = "\(memberID).jpg"
        let fileURL = photosDirectoryURL.appendingPathComponent(filename)
        if let data = image.jpegData(compressionQuality: 0.85) {
            try? data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        }
        return "photo:\(filename)"
    }

    /// Saves raw image bytes directly (preserving EXIF — including GPS coordinates).
    /// Use this instead of `savePhoto` whenever `PhotosPicker` raw `Data` is available.
    @discardableResult
    static func savePhotoData(_ data: Data, memberID: String) -> String {
        createPhotosDirectoryIfNeeded()
        let filename = "\(memberID).jpg"
        let fileURL = photosDirectoryURL.appendingPathComponent(filename)
        try? data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        return "photo:\(filename)"
    }

    /// Loads a UIImage given a `FamilyMember.imageURL` value.
    /// Handles both asset-catalog names and `"photo:…"` disk paths.
    static func loadImage(imageURL: String) -> UIImage? {
        if imageURL.hasPrefix("photo:") {
            let filename = String(imageURL.dropFirst("photo:".count))
            let fileURL = photosDirectoryURL.appendingPathComponent(filename)
            return UIImage(contentsOfFile: fileURL.path)
        }
        return UIImage(named: imageURL)
    }

    /// Returns the raw file bytes for a `"photo:…"` imageURL, preserving EXIF metadata.
    /// Returns `nil` for asset-catalog images or missing files.
    static func loadImageData(imageURL: String) -> Data? {
        guard imageURL.hasPrefix("photo:") else { return nil }
        let filename = String(imageURL.dropFirst("photo:".count))
        let fileURL = photosDirectoryURL.appendingPathComponent(filename)
        return try? Data(contentsOf: fileURL)
    }

    // MARK: - Reset

    /// Deletes all persisted data: user profile JSON, saved photos, and ML caches.
    /// After calling this, the next app launch will show the onboarding flow.
    static func deleteAll() {
        let fm = FileManager.default
        try? fm.removeItem(at: profileURL)
        try? fm.removeItem(at: photosDirectoryURL)
        try? fm.removeItem(at: documentsURL.appendingPathComponent("face_match_cache.json"))
        try? fm.removeItem(at: documentsURL.appendingPathComponent("scene_cache.json"))
    }

    // MARK: - Private

    private static func createPhotosDirectoryIfNeeded() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: photosDirectoryURL.path) {
            try? fm.createDirectory(
                at: photosDirectoryURL,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.complete]
            )
        }
    }
}
