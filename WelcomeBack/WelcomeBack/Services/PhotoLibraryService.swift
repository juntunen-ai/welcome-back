import Photos
import UIKit

// MARK: - PhotoMoment model

/// A time-clustered group of photos from the user's photo library (grouped by month).
struct PhotoMoment: Identifiable {
    let id: String              // "YYYY-MM"
    let title: String           // e.g. "May 2023"
    let subtitle: String        // e.g. "14 photos"
    let assetCount: Int
    var thumbnail: UIImage?
    let assetLocalIDs: [String] // PHAsset.localIdentifier for each photo
}

// MARK: - Service

/// Loads and clusters the user's photo library into month-based PhotoMoment groups.
@MainActor
final class PhotoLibraryService: ObservableObject {

    @Published var authorizationStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @Published var moments: [PhotoMoment] = []
    @Published var isLoading = false

    // MARK: - Public API

    func requestAuthorizationAndLoad() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        authorizationStatus = status
        guard status == .authorized || status == .limited else { return }
        await loadMoments()
    }

    /// Load full-resolution photos for a specific moment.
    func loadPhotos(for moment: PhotoMoment) async -> [UIImage] {
        let assets: [PHAsset] = await Task.detached(priority: .userInitiated) {
            let result = PHAsset.fetchAssets(
                withLocalIdentifiers: moment.assetLocalIDs, options: nil
            )
            var out: [PHAsset] = []
            result.enumerateObjects { asset, _, _ in out.append(asset) }
            return out
        }.value
        return await loadFullImages(from: assets)
    }

    // MARK: - Moment loading

    private func loadMoments() async {
        isLoading = true

        let loaded: [PhotoMoment] = await Task.detached(priority: .userInitiated) {
            // 1. Fetch recent photos sorted by date descending (limit to 2000)
            let opts = PHFetchOptions()
            opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            opts.fetchLimit = 2000
            opts.predicate = NSPredicate(
                format: "mediaType = %d", PHAssetMediaType.image.rawValue
            )
            let fetchResult = PHAsset.fetchAssets(with: .image, options: opts)

            // 2. Group assets by YYYY-MM
            var groups: [String: [PHAsset]] = [:]
            var groupOrder: [String] = []
            fetchResult.enumerateObjects { asset, _, _ in
                guard let date = asset.creationDate else { return }
                let comps = Calendar.current.dateComponents([.year, .month], from: date)
                guard let y = comps.year, let m = comps.month else { return }
                let key = String(format: "%04d-%02d", y, m)
                if groups[key] == nil {
                    groupOrder.append(key)
                    groups[key] = []
                }
                groups[key]!.append(asset)
            }

            // 3. Build PhotoMoments with thumbnails
            let thumbOptions = PHImageRequestOptions()
            thumbOptions.isSynchronous = true
            thumbOptions.deliveryMode = .fastFormat
            thumbOptions.isNetworkAccessAllowed = false

            let monthFormatter = DateFormatter()
            monthFormatter.dateFormat = "MMMM yyyy"

            return groupOrder.compactMap { key -> PhotoMoment? in
                guard let assets = groups[key], !assets.isEmpty else { return nil }

                // Title from first asset's date
                let titleDate = assets.first?.creationDate ?? Date()
                let title = monthFormatter.string(from: titleDate)
                let subtitle = "\(assets.count) photo\(assets.count == 1 ? "" : "s")"

                // Thumbnail from first asset
                var thumbnail: UIImage?
                if let first = assets.first {
                    PHImageManager.default().requestImage(
                        for: first,
                        targetSize: CGSize(width: 500, height: 500),
                        contentMode: .aspectFill,
                        options: thumbOptions
                    ) { img, _ in thumbnail = img }
                }

                return PhotoMoment(
                    id: key,
                    title: title,
                    subtitle: subtitle,
                    assetCount: assets.count,
                    thumbnail: thumbnail,
                    assetLocalIDs: assets.map { $0.localIdentifier }
                )
            }
        }.value

        moments = loaded
        isLoading = false
    }

    // MARK: - Full-resolution image loading

    private func loadFullImages(from assets: [PHAsset]) async -> [UIImage] {
        let size = CGSize(width: 1080, height: 1080)
        let reqOptions = PHImageRequestOptions()
        reqOptions.deliveryMode = .opportunistic
        reqOptions.isSynchronous = false
        reqOptions.isNetworkAccessAllowed = true

        return await withTaskGroup(of: (Int, UIImage?).self) { group in
            for (index, asset) in assets.enumerated() {
                group.addTask {
                    await withCheckedContinuation { continuation in
                        nonisolated(unsafe) var resumed = false
                        PHImageManager.default().requestImage(
                            for: asset,
                            targetSize: size,
                            contentMode: .aspectFill,
                            options: reqOptions
                        ) { image, info in
                            let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                            if isDegraded { return }
                            guard !resumed else { return }
                            resumed = true
                            continuation.resume(returning: (index, image))
                        }
                    }
                }
            }
            var pairs: [(Int, UIImage)] = []
            for await (index, image) in group {
                if let image { pairs.append((index, image)) }
            }
            return pairs.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }
}
