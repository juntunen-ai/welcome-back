import Photos
import UIKit
import Vision
import CoreLocation

// MARK: - Service

/// Scans the photo library for family members using on-device face recognition
/// and builds one MemoryAlbum per person.
@MainActor
final class PhotoLibraryService: ObservableObject {

    @Published var authorizationStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @Published var albums: [MemoryAlbum] = []
    @Published var isLoading = false
    @Published var isScanningInBackground = false

    private var backgroundScanTask: Task<Void, Never>?

    // MARK: - Public API

    func requestAuthorizationAndLoad(familyMembers: [FamilyMember] = []) async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        authorizationStatus = status
        guard status == .authorized || status == .limited else { return }
        await loadAlbums(familyMembers: familyMembers)
    }

    /// Load full-resolution PhotoItems for an album (carries date + location metadata).
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

    private func loadAlbums(familyMembers: [FamilyMember]) async {
        guard !familyMembers.isEmpty else {
            albums = []
            isLoading = false
            return
        }

        backgroundScanTask?.cancel()
        isLoading = true
        isScanningInBackground = true
        let capturedMembers = familyMembers

        backgroundScanTask = Task { [weak self] in
            guard let self else { return }

            let personAlbums = await Task.detached(priority: .background) {
                await PhotoLibraryService.buildPersonAlbums(familyMembers: capturedMembers)
            }.value

            guard !Task.isCancelled else { return }
            self.albums = personAlbums
            self.isLoading = false
            self.isScanningInBackground = false
        }
    }

    // MARK: - Person Albums (face feature print matching)

    private nonisolated static func buildPersonAlbums(familyMembers: [FamilyMember]) async -> [MemoryAlbum] {
        // Build feature prints from each family member's profile photo
        var memberPrints: [(id: String, name: String, print: VNFeaturePrintObservation)] = []
        for member in familyMembers {
            guard !member.imageURL.isEmpty,
                  let img = PersistenceService.loadImage(imageURL: member.imageURL),
                  let fp  = faceFeaturePrint(from: img) else { continue }
            memberPrints.append((id: member.id, name: member.name, print: fp))
        }
        guard !memberPrints.isEmpty else { return [] }

        var cache = loadFaceCache()

        // Fetch up to 500 most-recent non-screenshot images
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

            let photoImage = await loadThumbnailAsync(for: asset, size: CGSize(width: 300, height: 300))
            cache.processedIDs.insert(assetID)
            guard let img = photoImage else { continue }

            let matched = matchFaces(in: img, against: memberPrints)
            if !matched.isEmpty { cache.matches[assetID] = matched }
        }
        saveFaceCache(cache)

        // Build one album per family member from cached matches
        let assetByID: [String: PHAsset] = {
            var d: [String: PHAsset] = [:]
            result.enumerateObjects { a, _, _ in d[a.localIdentifier] = a }
            return d
        }()

        var memberAssets: [String: [PHAsset]] = [:]
        for (assetID, memberIDs) in cache.matches {
            guard let asset = assetByID[assetID] else { continue }
            for mid in memberIDs { memberAssets[mid, default: []].append(asset) }
        }

        let memberNameByID = Dictionary(uniqueKeysWithValues: memberPrints.map { ($0.id, $0.name) })

        var result2: [MemoryAlbum] = []
        for (memberID, assets) in memberAssets {
            guard assets.count >= 2, let name = memberNameByID[memberID] else { continue }
            let sorted = assets.sorted { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }

            // Prefer the member's own profile photo as album cover
            var thumbnail: UIImage?
            if let member = familyMembers.first(where: { $0.id == memberID }),
               !member.imageURL.isEmpty {
                thumbnail = PersistenceService.loadImage(imageURL: member.imageURL)
            }
            if thumbnail == nil {
                thumbnail = await loadThumbnailAsync(for: sorted.first)
            }

            result2.append(MemoryAlbum(
                id: "person-\(memberID)",
                title: name,
                subtitle: seasonYear(from: sorted.first?.creationDate),
                theme: .person(familyMemberID: memberID, name: name),
                assetLocalIDs: sorted.prefix(10).map { $0.localIdentifier },
                thumbnail: thumbnail
            ))
        }
        return result2.sorted { $0.title < $1.title }
    }

    private nonisolated static func seasonYear(from date: Date?) -> String {
        guard let date else { return "" }
        let cal = Calendar.current
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

    private nonisolated static func faceFeaturePrint(from image: UIImage) -> VNFeaturePrintObservation? {
        guard let cg = image.cgImage else { return nil }
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        let faceReq = VNDetectFaceRectanglesRequest()
        try? handler.perform([faceReq])

        let cropCG = faceReq.results?.first.flatMap { cropFace(from: cg, obs: $0) } ?? cg

        let printReq = VNGenerateImageFeaturePrintRequest()
        let printHandler = VNImageRequestHandler(cgImage: cropCG, options: [:])
        try? printHandler.perform([printReq])
        return printReq.results?.first
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

    private nonisolated static func matchFaces(
        in image: UIImage,
        against members: [(id: String, name: String, print: VNFeaturePrintObservation)]
    ) -> [String] {
        guard let cg = image.cgImage else { return [] }
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        let faceReq = VNDetectFaceRectanglesRequest()
        guard (try? handler.perform([faceReq])) != nil,
              let faces = faceReq.results, !faces.isEmpty else { return [] }

        var matched = Set<String>()
        for face in faces {
            guard let faceCG = cropFace(from: cg, obs: face) else { continue }
            let printReq = VNGenerateImageFeaturePrintRequest()
            let ph = VNImageRequestHandler(cgImage: faceCG, options: [:])
            guard (try? ph.perform([printReq])) != nil,
                  let fp = printReq.results?.first else { continue }
            for member in members {
                var dist: Float = 0
                if (try? fp.computeDistance(&dist, to: member.print)) != nil, dist < 0.85 {
                    matched.insert(member.id)
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

    // MARK: - Face cache (Documents/face_match_cache.json)

    private struct FaceMatchCache: Codable {
        var processedIDs: Set<String> = []
        var matches: [String: [String]] = [:]   // assetLocalIdentifier → [familyMemberID]
    }

    nonisolated static var faceCacheURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("face_match_cache.json")
    }

    private nonisolated static func loadFaceCache() -> FaceMatchCache {
        guard let data  = try? Data(contentsOf: faceCacheURL),
              let cache = try? JSONDecoder().decode(FaceMatchCache.self, from: data) else {
            return FaceMatchCache()
        }
        return cache
    }

    private nonisolated static func saveFaceCache(_ cache: FaceMatchCache) {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        try? data.write(to: faceCacheURL, options: .atomic)
    }
}
