import Photos
import UIKit
import Vision
import CoreLocation

/// Scans the photo library for family members using on-device face recognition
/// and builds one MemoryAlbum per person.
@MainActor
final class PhotoLibraryService: ObservableObject {

    @Published var authorizationStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @Published var albums: [MemoryAlbum] = []
    @Published var isScanningInBackground = false

    private var backgroundScanTask: Task<Void, Never>?

    // MARK: - Public API

    func requestAuthorizationAndLoad(familyMembers: [FamilyMember] = []) async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        authorizationStatus = status
        guard status == .authorized || status == .limited else { return }
        loadAlbums(familyMembers: familyMembers)
    }

    func loadPhotos(for album: MemoryAlbum) async -> [PhotoItem] {
        let assets: [PHAsset] = await Task.detached(priority: .userInitiated) {
            let result = PHAsset.fetchAssets(withLocalIdentifiers: album.assetLocalIDs, options: nil)
            var out: [PHAsset] = []
            result.enumerateObjects { a, _, _ in out.append(a) }
            return out
        }.value
        return await loadFullPhotoItems(from: assets)
    }

    // MARK: - Album loading

    /// Creates one placeholder album per family member immediately (non-async),
    /// then runs face recognition in the background and replaces albums when done.
    private func loadAlbums(familyMembers: [FamilyMember]) {
        guard !familyMembers.isEmpty else {
            albums = []
            return
        }

        // Show tiles right away — profile photo as cover, photos populated later.
        albums = familyMembers.map { member in
            MemoryAlbum(
                id: "person-\(member.id)",
                title: member.name,
                subtitle: "",
                theme: .person(familyMemberID: member.id, name: member.name),
                assetLocalIDs: [],
                thumbnail: member.imageURL.isEmpty
                    ? nil
                    : PersistenceService.loadImage(imageURL: member.imageURL)
            )
        }.sorted { $0.title < $1.title }

        // Background face-recognition scan — doesn't block the UI.
        backgroundScanTask?.cancel()
        isScanningInBackground = true
        let captured = familyMembers

        backgroundScanTask = Task { [weak self] in
            guard let self else { return }
            let result = await Task.detached(priority: .background) {
                await PhotoLibraryService.buildPersonAlbums(familyMembers: captured)
            }.value
            guard !Task.isCancelled else { return }
            self.albums = result
            self.isScanningInBackground = false
        }
    }

    // MARK: - Person Albums (face feature print matching)

    private nonisolated static func buildPersonAlbums(familyMembers: [FamilyMember]) async -> [MemoryAlbum] {
        // Build feature prints from each family member's profile photo.
        // isFaceBased = true  → profile photo had a detectable face → match against face crops
        // isFaceBased = false → profile photo had no face (pet/object) → match against full image
        var memberPrints: [(id: String, print: VNFeaturePrintObservation, isFaceBased: Bool)] = []
        for member in familyMembers {
            guard !member.imageURL.isEmpty,
                  let img = PersistenceService.loadImage(imageURL: member.imageURL),
                  let (fp, isFaceBased) = faceFeaturePrint(from: img) else { continue }
            memberPrints.append((id: member.id, print: fp, isFaceBased: isFaceBased))
        }

        var cache = loadFaceCache()

        if !memberPrints.isEmpty {
            // Fetch up to 500 most-recent non-screenshot images.
            let opts = PHFetchOptions()
            opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            opts.fetchLimit = 500
            opts.predicate = NSPredicate(
                format: "mediaType = %d AND NOT (mediaSubtype & %d) != 0",
                PHAssetMediaType.image.rawValue,
                PHAssetMediaSubtype.photoScreenshot.rawValue
            )
            let result = PHAsset.fetchAssets(with: .image, options: opts)
            var assets: [PHAsset] = []
            result.enumerateObjects { a, _, _ in assets.append(a) }

            for asset in assets {
                if Task.isCancelled { break }
                let assetID = asset.localIdentifier
                guard !cache.processedIDs.contains(assetID) else { continue }

                let img = await loadThumbnailAsync(for: asset, size: CGSize(width: 300, height: 300))
                cache.processedIDs.insert(assetID)
                guard let img else { continue }

                let matched = matchFaces(in: img, against: memberPrints)
                if !matched.isEmpty { cache.matches[assetID] = matched }
            }
            saveFaceCache(cache)
        }

        // Collect matched assets per member.
        let allIDs = Array(Set(cache.matches.keys))
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: allIDs, options: nil)
        var assetByID: [String: PHAsset] = [:]
        fetchResult.enumerateObjects { a, _, _ in assetByID[a.localIdentifier] = a }

        var memberAssets: [String: [PHAsset]] = [:]
        for (assetID, memberIDs) in cache.matches {
            guard let asset = assetByID[assetID] else { continue }
            for mid in memberIDs { memberAssets[mid, default: []].append(asset) }
        }

        // Build one album per family member — always, even if no photos matched yet.
        var albums: [MemoryAlbum] = []
        for member in familyMembers {
            let matched = (memberAssets[member.id] ?? [])
                .sorted { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }

            // Cover: member profile photo preferred; fall back to best matched photo.
            var thumbnail: UIImage?
            if !member.imageURL.isEmpty {
                thumbnail = PersistenceService.loadImage(imageURL: member.imageURL)
            }
            if thumbnail == nil, let first = matched.first {
                thumbnail = await loadThumbnailAsync(for: first)
            }

            albums.append(MemoryAlbum(
                id: "person-\(member.id)",
                title: member.name,
                subtitle: seasonYear(from: matched.first?.creationDate),
                theme: .person(familyMemberID: member.id, name: member.name),
                assetLocalIDs: matched.prefix(10).map { $0.localIdentifier },
                thumbnail: thumbnail
            ))
        }
        return albums.sorted { $0.title < $1.title }
    }

    // MARK: - Season subtitle

    private nonisolated static func seasonYear(from date: Date?) -> String {
        guard let date else { return "" }
        let cal   = Calendar.current
        let month = cal.component(.month, from: date)
        let year  = cal.component(.year,  from: date)
        let season: String
        switch month {
        case 3...5:  season = "Spring"
        case 6...8:  season = "Summer"
        case 9...11: season = "Autumn"
        default:     season = "Winter"
        }
        return "\(season) \(year)"
    }

    // MARK: - Face helpers

    /// Generates a feature print for a profile photo.
    /// Returns `(print, isFaceBased)` where `isFaceBased` is true when a face was
    /// detected and the print was generated from the face crop rather than the full image.
    /// Returns nil when the image cannot be processed at all.
    private nonisolated static func faceFeaturePrint(from image: UIImage) -> (VNFeaturePrintObservation, Bool)? {
        guard let cg = image.cgImage else { return nil }
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        let faceReq = VNDetectFaceRectanglesRequest()
        try? handler.perform([faceReq])

        let isFaceBased: Bool
        let targetCG: CGImage
        if let face = faceReq.results?.first, let faceCG = cropFace(from: cg, obs: face) {
            targetCG  = faceCG
            isFaceBased = true
        } else {
            targetCG  = cg
            isFaceBased = false
        }

        let printReq = VNGenerateImageFeaturePrintRequest()
        let printHandler = VNImageRequestHandler(cgImage: targetCG, options: [:])
        try? printHandler.perform([printReq])
        guard let fp = printReq.results?.first else { return nil }
        return (fp, isFaceBased)
    }

    private nonisolated static func cropFace(from cg: CGImage, obs: VNFaceObservation) -> CGImage? {
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        let bb = obs.boundingBox
        let padX = bb.width  * w * 0.3
        let padY = bb.height * h * 0.3
        let rect = CGRect(
            x:      max(0, bb.origin.x * w - padX),
            y:      max(0, (1 - bb.origin.y - bb.height) * h - padY),
            width:  min(bb.width  * w + padX * 2, w),
            height: min(bb.height * h + padY * 2, h)
        ).integral
        return cg.cropping(to: rect)
    }

    /// Matches a library photo against member feature prints.
    /// - Face-based members (humans): detected face crops are compared → threshold 0.85
    /// - Full-image members (pets/objects): the whole image print is compared → threshold 0.60
    private nonisolated static func matchFaces(
        in image: UIImage,
        against members: [(id: String, print: VNFeaturePrintObservation, isFaceBased: Bool)]
    ) -> [String] {
        guard let cg = image.cgImage else { return [] }
        var matched = Set<String>()

        let faceMembers  = members.filter {  $0.isFaceBased }
        let imageMembers = members.filter { !$0.isFaceBased }

        // ── Path A: face-based members ──────────────────────────────────────────
        // Detect faces in the library photo and compare each face crop to the member's face print.
        if !faceMembers.isEmpty {
            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            let faceReq = VNDetectFaceRectanglesRequest()
            if (try? handler.perform([faceReq])) != nil,
               let faces = faceReq.results, !faces.isEmpty {
                for face in faces {
                    guard let faceCG = cropFace(from: cg, obs: face) else { continue }
                    let printReq = VNGenerateImageFeaturePrintRequest()
                    let ph = VNImageRequestHandler(cgImage: faceCG, options: [:])
                    guard (try? ph.perform([printReq])) != nil,
                          let fp = printReq.results?.first else { continue }
                    for member in faceMembers {
                        var dist: Float = 0
                        if (try? fp.computeDistance(&dist, to: member.print)) != nil, dist < 0.85 {
                            matched.insert(member.id)
                        }
                    }
                }
            }
        }

        // ── Path B: full-image members (pets, objects) ──────────────────────────
        // Generate a feature print for the entire library photo and compare it to
        // the member's full-image print. This finds photos that look like the pet/object.
        if !imageMembers.isEmpty {
            let printReq = VNGenerateImageFeaturePrintRequest()
            let handler  = VNImageRequestHandler(cgImage: cg, options: [:])
            if (try? handler.perform([printReq])) != nil,
               let fp = printReq.results?.first {
                for member in imageMembers {
                    var dist: Float = 0
                    if (try? fp.computeDistance(&dist, to: member.print)) != nil, dist < 0.60 {
                        matched.insert(member.id)
                    }
                }
            }
        }

        return Array(matched)
    }

    // MARK: - Full-resolution PhotoItem loading

    private func loadFullPhotoItems(from assets: [PHAsset]) async -> [PhotoItem] {
        let size = CGSize(width: 1080, height: 1080)
        let opts = PHImageRequestOptions()
        opts.deliveryMode = .highQualityFormat
        opts.isSynchronous = false
        opts.isNetworkAccessAllowed = true

        return await withTaskGroup(of: (Int, String, UIImage?, Date?, CLLocation?).self) { group in
            for (index, asset) in assets.enumerated() {
                let assetID  = asset.localIdentifier
                let date     = asset.creationDate
                let location = asset.location
                group.addTask {
                    await withCheckedContinuation { cont in
                        nonisolated(unsafe) var resumed = false
                        PHImageManager.default().requestImage(
                            for: asset, targetSize: size,
                            contentMode: .aspectFill, options: opts
                        ) { image, _ in
                            guard !resumed else { return }
                            resumed = true
                            cont.resume(returning: (index, assetID, image, date, location))
                        }
                    }
                }
            }
            var results: [(Int, String, UIImage, Date?, CLLocation?)] = []
            for await (index, id, image, date, loc) in group {
                if let image { results.append((index, id, image, date, loc)) }
            }
            return results.sorted { $0.0 < $1.0 }.map { (_, id, img, date, loc) in
                PhotoItem(id: id, image: img, date: date, location: loc)
            }
        }
    }

    // MARK: - Thumbnail helper

    private nonisolated static func loadThumbnailAsync(
        for asset: PHAsset?,
        size: CGSize = CGSize(width: 400, height: 400)
    ) async -> UIImage? {
        guard let asset else { return nil }
        let opts = PHImageRequestOptions()
        opts.deliveryMode = .fastFormat
        opts.isSynchronous = false
        opts.isNetworkAccessAllowed = false
        return await withCheckedContinuation { cont in
            nonisolated(unsafe) var resumed = false
            PHImageManager.default().requestImage(
                for: asset, targetSize: size,
                contentMode: .aspectFill, options: opts
            ) { img, _ in
                guard !resumed else { return }
                resumed = true
                cont.resume(returning: img)
            }
        }
    }

    // MARK: - Face cache

    private struct FaceMatchCache: Codable {
        /// Bump this integer whenever the matching algorithm changes so that stale
        /// caches from older algorithm versions are automatically discarded.
        var version: Int = 2
        var processedIDs: Set<String> = []
        var matches: [String: [String]] = [:]
    }

    nonisolated static var faceCacheURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("face_match_cache.json")
    }

    private nonisolated static func loadFaceCache() -> FaceMatchCache {
        guard let data  = try? Data(contentsOf: faceCacheURL),
              let cache = try? JSONDecoder().decode(FaceMatchCache.self, from: data),
              cache.version == FaceMatchCache().version   // reject caches built by old algorithm versions
        else { return FaceMatchCache() }
        return cache
    }

    private nonisolated static func saveFaceCache(_ cache: FaceMatchCache) {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        try? data.write(to: faceCacheURL, options: .atomic)
    }
}
