import Foundation
import UIKit

/// Handles all on-disk persistence for Welcome Back.
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
            try data.write(to: profileURL, options: .atomic)
        } catch {
            print("[Persistence] Save failed: \(error)")
        }
    }

    static func load() -> UserProfile? {
        guard FileManager.default.fileExists(atPath: profileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: profileURL)
            return try JSONDecoder().decode(UserProfile.self, from: data)
        } catch {
            print("[Persistence] Load failed: \(error)")
            return nil
        }
    }

    // MARK: - Photos

    /// Saves JPEG data for a family member photo and returns the `imageURL`
    /// string to store on the `FamilyMember` (prefixed with `"photo:"`).
    @discardableResult
    static func savePhoto(_ image: UIImage, memberID: String) -> String {
        createPhotosDirectoryIfNeeded()
        let filename = "\(memberID).jpg"
        let fileURL = photosDirectoryURL.appendingPathComponent(filename)
        if let data = image.jpegData(compressionQuality: 0.85) {
            try? data.write(to: fileURL, options: .atomic)
        }
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

    // MARK: - Reset

    /// Deletes all persisted data: the user profile JSON and all saved photos.
    /// After calling this, the next app launch will show the onboarding flow.
    static func deleteAll() {
        let fm = FileManager.default
        try? fm.removeItem(at: profileURL)
        try? fm.removeItem(at: photosDirectoryURL)
    }

    // MARK: - Private

    private static func createPhotosDirectoryIfNeeded() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: photosDirectoryURL.path) {
            try? fm.createDirectory(at: photosDirectoryURL,
                                    withIntermediateDirectories: true)
        }
    }
}
