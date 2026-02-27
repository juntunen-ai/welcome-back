import SwiftUI
import Photos
import Vision

// MARK: - View Model

@MainActor
final class MemoryCarouselViewModel: ObservableObject {

    @Published var photos: [UIImage] = []
    @Published var currentIndex: Int = 0
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private let imageManager = PHCachingImageManager()

    // MARK: - Main Load Entry Point

    func load(for memory: Memory) async {
        isLoading = true
        errorMessage = nil
        photos = []
        currentIndex = 0

        // Permission was already requested by MemoriesView on appear.
        // Just read the current status — no dialog, no navigation disruption.
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            errorMessage = "Photo library access is needed to show your memories.\nGo to Settings → Privacy → Photos → Welcome Back."
            isLoading = false
            return
        }

        // Step 1: Try to generate a seed feature print from the memory's asset catalog image.
        let seedPrint: VNFeaturePrintObservation? = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let seedImage = UIImage(named: memory.imageURL) else {
                    continuation.resume(returning: nil)
                    return
                }
                let print = Self.featurePrint(for: seedImage)
                continuation.resume(returning: print)
            }
        }

        // Step 2: Fetch up to 200 recent PHAssets (images only).
        let candidates = fetchRecent(limit: 200)

        if candidates.isEmpty {
            photos = []
            isLoading = false
            return
        }

        // Step 3: If we have a valid seed print, run similarity search.
        //         Otherwise fall back to the 20 most recent photos.
        if let seedPrint {
            let topAssets = await rankAssets(candidates, against: seedPrint)
            photos = await loadImages(from: topAssets)
        } else {
            // Fallback: no seed image or feature print generation failed.
            photos = await loadImages(from: Array(candidates.prefix(20)))
        }

        isLoading = false
    }

    // MARK: - Feature-print similarity ranking

    /// On a background queue: for each candidate asset, generate a 224x224 thumbnail,
    /// compute the Vision feature print, measure distance from the seed print, then
    /// return the top-20 assets sorted by ascending distance.
    private func rankAssets(
        _ assets: [PHAsset],
        against seedPrint: VNFeaturePrintObservation
    ) async -> [PHAsset] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let thumbnailSize = CGSize(width: 224, height: 224)
                let reqOptions = PHImageRequestOptions()
                reqOptions.isSynchronous = true          // synchronous is fine on background queue
                reqOptions.deliveryMode = .fastFormat
                reqOptions.isNetworkAccessAllowed = false // thumbnails only from local cache

                var scored: [(asset: PHAsset, distance: Float)] = []
                scored.reserveCapacity(assets.count)

                for asset in assets {
                    var thumbnail: UIImage?
                    PHImageManager.default().requestImage(
                        for: asset,
                        targetSize: thumbnailSize,
                        contentMode: .aspectFill,
                        options: reqOptions
                    ) { image, _ in
                        thumbnail = image
                    }

                    guard let thumb = thumbnail,
                          let candidatePrint = Self.featurePrint(for: thumb) else {
                        continue
                    }

                    var distance: Float = 0
                    do {
                        try seedPrint.computeDistance(&distance, to: candidatePrint)
                    } catch {
                        continue
                    }
                    scored.append((asset: asset, distance: distance))
                }

                // Sort ascending (lower distance = more similar) and take top 20.
                let topAssets = scored
                    .sorted { $0.distance < $1.distance }
                    .prefix(20)
                    .map { $0.asset }

                continuation.resume(returning: topAssets)
            }
        }
    }

    // MARK: - Feature print helper

    private static func featurePrint(for image: UIImage) -> VNFeaturePrintObservation? {
        guard let cgImage = image.cgImage else { return nil }
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
        return request.results?.first as? VNFeaturePrintObservation
    }

    // MARK: - PHAsset fetch

    private func fetchRecent(limit: Int) -> [PHAsset] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = limit
        options.predicate = NSPredicate(
            format: "mediaType = %d", PHAssetMediaType.image.rawValue
        )
        var assets: [PHAsset] = []
        let result = PHAsset.fetchAssets(with: .image, options: options)
        result.enumerateObjects { asset, _, _ in assets.append(asset) }
        return assets
    }

    // MARK: - Full-resolution image loading

    /// Load assets at 1080x1080 quality using `withCheckedContinuation`.
    /// Guards against the PHImageManager double-callback (degraded + final) via
    /// a `nonisolated(unsafe) var resumed` flag.
    private func loadImages(from assets: [PHAsset]) async -> [UIImage] {
        let size = CGSize(width: 1080, height: 1080)
        let reqOptions = PHImageRequestOptions()
        reqOptions.deliveryMode = .opportunistic
        reqOptions.isSynchronous = false
        reqOptions.isNetworkAccessAllowed = true

        return await withTaskGroup(of: (Int, UIImage?).self) { group in
            for (index, asset) in assets.enumerated() {
                group.addTask {
                    await withCheckedContinuation { (continuation: CheckedContinuation<(Int, UIImage?), Never>) in
                        // PHImageManager may call back twice (degraded preview + final full-res).
                        // The nonisolated(unsafe) flag ensures we resume the continuation only once.
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
            // Preserve original ranking order.
            return pairs.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }
}

// MARK: - View

struct MemoryCarouselView: View {

    let memory: Memory
    @StateObject private var vm = MemoryCarouselViewModel()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if vm.isLoading {
                loadingView
            } else if let error = vm.errorMessage {
                errorView(error)
            } else if vm.photos.isEmpty {
                emptyView
            } else {
                carouselView
            }
        }
        .navigationTitle(memory.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationBarBackButtonHidden(false)
        .task { await vm.load(for: memory) }
    }

    // MARK: - Carousel

    private var carouselView: some View {
        VStack(spacing: 0) {
            // "N of M" counter
            Text("\(vm.currentIndex + 1) of \(vm.photos.count)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .padding(.top, 16)
                .padding(.bottom, 12)

            // Swipeable photo pages
            TabView(selection: $vm.currentIndex) {
                ForEach(vm.photos.indices, id: \.self) { i in
                    Image(uiImage: vm.photos[i])
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal, 16)
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(maxHeight: .infinity)

            // Dot indicators
            HStack(spacing: 6) {
                ForEach(vm.photos.indices, id: \.self) { i in
                    Circle()
                        .fill(i == vm.currentIndex ? Color.accentYellow : Color.white.opacity(0.3))
                        .frame(width: i == vm.currentIndex ? 8 : 6,
                               height: i == vm.currentIndex ? 8 : 6)
                        .animation(.spring(response: 0.3), value: vm.currentIndex)
                }
            }
            .padding(.bottom, 48)
            .padding(.top, 16)
        }
    }

    // MARK: - State views

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.accentYellow)
                .scaleEffect(1.4)
            Text("Finding similar photos…")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.slash")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.3))
            Text(message)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.3))
            Text("No photos found for this memory.")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
}

#Preview {
    MemoryCarouselView(memory: Memory.mockData[0])
}
