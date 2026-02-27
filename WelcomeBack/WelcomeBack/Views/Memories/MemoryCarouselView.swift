import SwiftUI
import Photos

// MARK: - View Model

@MainActor
final class MemoryCarouselViewModel: ObservableObject {

    @Published var photos: [UIImage] = []
    @Published var currentIndex: Int = 0
    @Published var authStatus: PHAuthorizationStatus = .notDetermined
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    private let imageManager = PHCachingImageManager()

    // MARK: - Load

    func load(for memory: Memory) async {
        isLoading = true
        errorMessage = nil

        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        authStatus = status

        guard status == .authorized || status == .limited else {
            errorMessage = "Photo library access is needed to show your memories.\nGo to Settings → Privacy → Photos → Welcome Back."
            isLoading = false
            return
        }

        let keywords = searchKeywords(for: memory)
        let assets = fetchAssets(keywords: keywords)

        if assets.isEmpty {
            // Fallback: fetch 20 most recent photos
            let recent = fetchRecent(limit: 20)
            photos = await loadImages(from: recent)
        } else {
            photos = await loadImages(from: assets)
        }

        isLoading = false
    }

    // MARK: - Keyword extraction

    private func searchKeywords(for memory: Memory) -> [String] {
        var words: [String] = []

        // Split title into significant words (3+ chars)
        let titleWords = memory.title
            .components(separatedBy: .whitespaces)
            .filter { $0.count >= 3 }
        words.append(contentsOf: titleWords)

        // Add category name
        words.append(memory.category.rawValue)

        return words
    }

    // MARK: - PHAsset fetch

    private func fetchAssets(keywords: [String]) -> [PHAsset] {
        var results: [PHAsset] = []

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = 40

        // Search smart albums by title keywords
        let albumResult = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum, subtype: .any, options: nil
        )
        albumResult.enumerateObjects { collection, _, _ in
            let name = collection.localizedTitle?.lowercased() ?? ""
            if keywords.contains(where: { name.contains($0.lowercased()) }) {
                let assets = PHAsset.fetchAssets(in: collection, options: options)
                assets.enumerateObjects { asset, _, _ in
                    if asset.mediaType == .image { results.append(asset) }
                }
            }
        }

        // Also search user albums
        let userAlbums = PHAssetCollection.fetchAssetCollections(
            with: .album, subtype: .any, options: nil
        )
        userAlbums.enumerateObjects { collection, _, _ in
            let name = collection.localizedTitle?.lowercased() ?? ""
            if keywords.contains(where: { name.contains($0.lowercased()) }) {
                let assets = PHAsset.fetchAssets(in: collection, options: options)
                assets.enumerateObjects { asset, _, _ in
                    if asset.mediaType == .image && !results.contains(where: { $0.localIdentifier == asset.localIdentifier }) {
                        results.append(asset)
                    }
                }
            }
        }

        return Array(results.prefix(20))
    }

    private func fetchRecent(limit: Int) -> [PHAsset] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = limit
        options.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)

        var assets: [PHAsset] = []
        let result = PHAsset.fetchAssets(with: .image, options: options)
        result.enumerateObjects { asset, _, _ in assets.append(asset) }
        return assets
    }

    // MARK: - Image loading

    private func loadImages(from assets: [PHAsset]) async -> [UIImage] {
        let size = CGSize(width: 1080, height: 1080)
        let reqOptions = PHImageRequestOptions()
        reqOptions.deliveryMode = .highQualityFormat
        reqOptions.isSynchronous = false
        reqOptions.isNetworkAccessAllowed = true

        return await withTaskGroup(of: (Int, UIImage?).self) { group in
            for (index, asset) in assets.enumerated() {
                group.addTask {
                    await withCheckedContinuation { continuation in
                        self.imageManager.requestImage(
                            for: asset,
                            targetSize: size,
                            contentMode: .aspectFill,
                            options: reqOptions
                        ) { image, _ in
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

// MARK: - View

struct MemoryCarouselView: View {

    let memory: Memory
    @StateObject private var vm = MemoryCarouselViewModel()
    @Environment(\.dismiss) private var dismiss

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

            // Close button always visible top-right
            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 20)
                }
                .padding(.top, 56)
                Spacer()
            }
        }
        .task { await vm.load(for: memory) }
    }

    // MARK: - Carousel

    private var carouselView: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 4) {
                Text(memory.title)
                    .font(.system(size: 22, weight: .black))
                    .foregroundColor(.white)
                Text("\(vm.currentIndex + 1) of \(vm.photos.count)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.top, 60)
            .padding(.bottom, 16)

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

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.accentYellow)
                .scaleEffect(1.4)
            Text("Finding your photos…")
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
            Text("No photos found for this memory.\nTry adding photos to an album named \"\(memory.title)\".")
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
