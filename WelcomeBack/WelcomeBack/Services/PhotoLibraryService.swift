import Photos
import UIKit
import Vision
import CoreLocation

// MARK: - Service

/// Loads photos from the user's library and clusters them into smart MemoryAlbum groups:
///   • Person albums  — face recognition via Vision (background scan, cached)
///   • Trip albums    — GPS clustering + reverse geocoding
///   • Holiday albums — calendar date matching (Christmas, Midsummer, Easter …)
///   • Scene albums   — on-device scene classification via VNClassifyImageRequest (background, cached)
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

    // MARK: - Album loading pipeline

    private func loadAlbums(familyMembers: [FamilyMember]) async {
        isLoading = true

        // Phase 1 — fast: holiday + trip albums from metadata
        let phase1 = await Task.detached(priority: .userInitiated) {
            let holidays = PhotoLibraryService.buildHolidayAlbums()
            let trips    = await PhotoLibraryService.buildTripAlbums()
            return holidays + trips
        }.value

        albums = phase1
        isLoading = false

        // Phase 2 — background: face recognition + scene classification
        backgroundScanTask?.cancel()
        isScanningInBackground = true
        let capturedMembers = familyMembers

        backgroundScanTask = Task { [weak self] in
            guard let self else { return }

            // Person albums first (more relevant to the user)
            let personAlbums = await Task.detached(priority: .background) {
                await PhotoLibraryService.buildPersonAlbums(familyMembers: capturedMembers)
            }.value

            guard !Task.isCancelled else { return }
            self.albums = personAlbums + self.albums

            // Scene albums
            let sceneAlbums = await Task.detached(priority: .background) {
                await PhotoLibraryService.buildSceneAlbums()
            }.value

            guard !Task.isCancelled else { return }
            self.albums = self.albums + sceneAlbums
            self.isScanningInBackground = false
        }
    }

    // MARK: - Phase 1a: Holiday Albums (calendar-based, instant)

    private nonisolated static func buildHolidayAlbums() -> [MemoryAlbum] {
        let opts = PHFetchOptions()
        opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        opts.fetchLimit = 5000
        opts.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        let result = PHAsset.fetchAssets(with: .image, options: opts)

        var groups: [String: [PHAsset]] = [:]
        result.enumerateObjects { asset, _, _ in
            guard let date = asset.creationDate,
                  let name = holidayName(for: date) else { return }
            groups[name, default: []].append(asset)
        }

        return groups.compactMap { name, assets -> MemoryAlbum? in
            guard assets.count >= 3 else { return nil }
            let sorted = assets.sorted { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }
            return MemoryAlbum(
                id: "holiday-\(name.lowercased().replacingOccurrences(of: " ", with: "-"))",
                title: name,
                subtitle: "\(sorted.count) photo\(sorted.count == 1 ? "" : "s")",
                theme: .holiday(name: name),
                assetLocalIDs: sorted.map { $0.localIdentifier },
                thumbnail: nil
            )
        }.sorted { $0.title < $1.title }
    }

    private nonisolated static func holidayName(for date: Date) -> String? {
        let cal = Calendar.current
        let month = cal.component(.month, from: date)
        let day   = cal.component(.day,   from: date)
        let year  = cal.component(.year,  from: date)
        switch (month, day) {
        case (12, 24), (12, 25), (12, 26): return "Christmas"
        case (12, 31): return "New Year's Eve"
        case (1, 1):   return "New Year"
        case (6, 20), (6, 21), (6, 22), (6, 23), (6, 24), (6, 25), (6, 26): return "Midsummer"
        case (2, 14):  return "Valentine's Day"
        default:
            let range = easterRange(year: year)
            if range.contains(where: { cal.isDate(date, inSameDayAs: $0) }) { return "Easter" }
            return nil
        }
    }

    /// Anonymous Gregorian algorithm for Easter Sunday ± adjacent days.
    private nonisolated static func easterRange(year: Int) -> [Date] {
        let a = year % 19, b = year / 100, c = year % 100
        let d = b / 4, e = b % 4, f = (b + 8) / 25
        let g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4, k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day   = ((h + l - 7 * m + 114) % 31) + 1
        var cal = Calendar.current
        cal.timeZone = TimeZone(identifier: "UTC")!
        guard let easter = cal.date(from: DateComponents(year: year, month: month, day: day)) else { return [] }
        return (-2...1).compactMap { cal.date(byAdding: .day, value: $0, to: easter) }
    }

    // MARK: - Phase 1b: Trip Albums (GPS clustering + geocoding)

    private nonisolated static func buildTripAlbums() async -> [MemoryAlbum] {
        let opts = PHFetchOptions()
        opts.predicate = NSPredicate(format: "mediaType = %d AND location != nil",
                                     PHAssetMediaType.image.rawValue)
        opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        opts.fetchLimit = 3000
        let result = PHAsset.fetchAssets(with: .image, options: opts)

        var pairs: [(PHAsset, CLLocation)] = []
        result.enumerateObjects { asset, _, _ in
            if let loc = asset.location { pairs.append((asset, loc)) }
        }
        guard !pairs.isEmpty else { return [] }

        // Cluster photos within 30 km of each other
        var clusters: [[(PHAsset, CLLocation)]] = []
        for pair in pairs {
            var added = false
            for i in clusters.indices {
                let centroid = clusterCentroid(clusters[i].map { $0.1 })
                if haversineKm(centroid, pair.1) < 30.0 {
                    clusters[i].append(pair)
                    added = true
                    break
                }
            }
            if !added { clusters.append([pair]) }
        }

        // Keep clusters with ≥ 5 photos spanning ≥ 1 calendar day
        let valid = clusters.filter { cluster in
            guard cluster.count >= 5 else { return false }
            let dates = cluster.compactMap { $0.0.creationDate }.sorted()
            guard let first = dates.first, let last = dates.last else { return false }
            return !Calendar.current.isDate(first, inSameDayAs: last)
        }
        guard !valid.isEmpty else { return [] }

        var albums: [MemoryAlbum] = []

        for (index, cluster) in valid.enumerated() {
            if Task.isCancelled { break }

            let centroid = clusterCentroid(cluster.map { $0.1 })
            let locationName = await geocode(centroid)
            let sorted = cluster.sorted {
                ($0.0.creationDate ?? .distantPast) > ($1.0.creationDate ?? .distantPast)
            }
            let thumbnail = await loadThumbnailAsync(for: sorted.first?.0)
            let title = locationName.map { "Trip to \($0)" } ?? "Trip \(index + 1)"
            let dates  = cluster.compactMap { $0.0.creationDate }.sorted()
            let subtitle = dateRangeSubtitle(from: dates.first, count: cluster.count)

            albums.append(MemoryAlbum(
                id: "trip-\(index)-\(Int(centroid.coordinate.latitude * 100))",
                title: title,
                subtitle: subtitle,
                theme: .trip(primaryLocation: locationName ?? ""),
                assetLocalIDs: sorted.map { $0.0.localIdentifier },
                thumbnail: thumbnail
            ))

            // Respect CLGeocoder rate limit
            if index < valid.count - 1 {
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
        }
        return albums
    }

    private nonisolated static func clusterCentroid(_ locs: [CLLocation]) -> CLLocation {
        let lat = locs.map { $0.coordinate.latitude }.reduce(0, +) / Double(locs.count)
        let lon = locs.map { $0.coordinate.longitude }.reduce(0, +) / Double(locs.count)
        return CLLocation(latitude: lat, longitude: lon)
    }

    private nonisolated static func haversineKm(_ a: CLLocation, _ b: CLLocation) -> Double {
        let R = 6371.0
        let lat1 = a.coordinate.latitude * .pi / 180
        let lat2 = b.coordinate.latitude * .pi / 180
        let dLat = (b.coordinate.latitude  - a.coordinate.latitude)  * .pi / 180
        let dLon = (b.coordinate.longitude - a.coordinate.longitude) * .pi / 180
        let x = sin(dLat/2)*sin(dLat/2) + cos(lat1)*cos(lat2)*sin(dLon/2)*sin(dLon/2)
        return R * 2 * atan2(sqrt(x), sqrt(1 - x))
    }

    private nonisolated static func geocode(_ location: CLLocation) async -> String? {
        do {
            let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
            guard let p = placemarks.first else { return nil }
            return p.locality ?? p.subLocality ?? p.administrativeArea
        } catch { return nil }
    }

    private nonisolated static func dateRangeSubtitle(from start: Date?, count: Int) -> String {
        let countStr = "\(count) photo\(count == 1 ? "" : "s")"
        guard let s = start else { return countStr }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM yyyy"
        return "\(countStr) • \(fmt.string(from: s))"
    }

    // MARK: - Phase 2a: Person Albums (face feature print matching, background)

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

        // Fetch up to 500 most-recent images
        let opts = PHFetchOptions()
        opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        opts.fetchLimit = 500
        opts.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
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

            // Prefer the member's own profile photo as album cover (file-system read, safe)
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
                subtitle: "\(sorted.count) photo\(sorted.count == 1 ? "" : "s") with \(name)",
                theme: .person(familyMemberID: memberID, name: name),
                assetLocalIDs: sorted.map { $0.localIdentifier },
                thumbnail: thumbnail
            ))
        }
        return result2.sorted { $0.title < $1.title }
    }

    /// Generate a face-based feature print from a UIImage (crops to largest detected face).
    /// NOTE: VNGenerateImageFeaturePrintRequest is a general visual similarity metric.
    /// When applied to face crops from both reference and query images it gives
    /// reasonable face-matching accuracy for this use case.
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
        let bb = obs.boundingBox          // normalized, origin = bottom-left
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

    // MARK: - Phase 2b: Scene Albums (VNClassifyImageRequest, background)

    private nonisolated static func buildSceneAlbums() async -> [MemoryAlbum] {
        var cache = loadSceneCache()

        let opts = PHFetchOptions()
        opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        opts.fetchLimit = 500
        opts.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        let result = PHAsset.fetchAssets(with: .image, options: opts)
        var assets: [PHAsset] = []
        result.enumerateObjects { a, _, _ in assets.append(a) }

        let sceneMap: [(keywords: [String], tag: String)] = [
            (["beach", "ocean", "sea", "coast", "shore"], "beach"),
            (["mountain", "cliff", "canyon", "alpine"],   "mountain"),
            (["snow", "ski", "snowfield", "blizzard"],    "winter"),
            (["forest", "woodland", "jungle", "grove"],   "forest"),
        ]

        for asset in assets {
            if Task.isCancelled { break }
            let assetID = asset.localIdentifier
            guard !cache.processedIDs.contains(assetID) else { continue }

            guard let img = await loadThumbnailAsync(for: asset, size: CGSize(width: 224, height: 224)),
                  let cgImage = img.cgImage else {
                cache.processedIDs.insert(assetID)
                continue
            }

            let classifyReq = VNClassifyImageRequest()
            let ph = VNImageRequestHandler(cgImage: cgImage, options: [:])
            if (try? ph.perform([classifyReq])) != nil {
                var tags: [String] = []
                for obs in (classifyReq.results ?? []) where obs.confidence > 0.4 {
                    let id = obs.identifier.lowercased()
                    for entry in sceneMap where entry.keywords.contains(where: { id.contains($0) }) {
                        if !tags.contains(entry.tag) { tags.append(entry.tag) }
                    }
                }
                if !tags.isEmpty { cache.scenes[assetID] = tags }
            }
            cache.processedIDs.insert(assetID)
        }
        saveSceneCache(cache)

        // Collect assets per tag
        var tagGroups: [String: [PHAsset]] = [:]
        let assetByID: [String: PHAsset] = {
            var d: [String: PHAsset] = [:]
            result.enumerateObjects { a, _, _ in d[a.localIdentifier] = a }
            return d
        }()
        for (assetID, tags) in cache.scenes {
            guard let asset = assetByID[assetID] else { continue }
            for tag in tags { tagGroups[tag, default: []].append(asset) }
        }

        let titleForTag: [String: String] = [
            "beach":    "Beach Days",
            "mountain": "Mountain Trips",
            "winter":   "Winter Adventures",
            "forest":   "Nature Walks",
        ]
        var sceneAlbums: [MemoryAlbum] = []
        for (tag, assets) in tagGroups {
            guard assets.count >= 3, let title = titleForTag[tag] else { continue }
            let sorted = assets.sorted { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }
            let thumbnail = await loadThumbnailAsync(for: sorted.first)
            sceneAlbums.append(MemoryAlbum(
                id: "scene-\(tag)",
                title: title,
                subtitle: "\(sorted.count) photo\(sorted.count == 1 ? "" : "s")",
                theme: .scene(tag: tag),
                assetLocalIDs: sorted.map { $0.localIdentifier },
                thumbnail: thumbnail
            ))
        }
        return sceneAlbums
    }

    // MARK: - Full-resolution PhotoItem loading

    private func loadFullPhotoItems(from assets: [PHAsset]) async -> [PhotoItem] {
        let size = CGSize(width: 1080, height: 1080)
        // .highQualityFormat guarantees exactly one callback per request,
        // preventing withCheckedContinuation from being abandoned.
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

    // MARK: - Shared helpers

    /// Async thumbnail loader — uses isSynchronous = false so the cooperative thread pool is never blocked.
    /// deliveryMode = .fastFormat guarantees exactly one callback, preventing continuation leaks.
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

    // MARK: - Scene cache (Documents/scene_cache.json)

    private struct SceneCache: Codable {
        var processedIDs: Set<String> = []
        var scenes: [String: [String]] = [:]    // assetLocalIdentifier → [tag]
    }

    nonisolated static var sceneCacheURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("scene_cache.json")
    }

    private nonisolated static func loadSceneCache() -> SceneCache {
        guard let data  = try? Data(contentsOf: sceneCacheURL),
              let cache = try? JSONDecoder().decode(SceneCache.self, from: data) else {
            return SceneCache()
        }
        return cache
    }

    private nonisolated static func saveSceneCache(_ cache: SceneCache) {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        try? data.write(to: sceneCacheURL, options: .atomic)
    }
}
