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

        var collected: [PHAsset] = []

        // 1. Date-range search (most relevant if memory has a date)
        if let dateRange = parseDateRange(from: memory.date) {
            let byDate = fetchByDateRange(from: dateRange.start, to: dateRange.end)
            collected.append(contentsOf: byDate)
        }

        // 2. Album name keyword search
        let keywords = searchKeywords(for: memory)
        let byAlbum = fetchByAlbumKeywords(keywords)
        for asset in byAlbum where !collected.contains(where: { $0.localIdentifier == asset.localIdentifier }) {
            collected.append(asset)
        }

        // 3. Filename / title keyword search across all photos
        let byFilename = fetchByFilenameKeywords(keywords)
        for asset in byFilename where !collected.contains(where: { $0.localIdentifier == asset.localIdentifier }) {
            collected.append(asset)
        }

        // 4. Fallback — 20 most recent photos
        if collected.isEmpty {
            collected = fetchRecent(limit: 20)
        }

        photos = await loadImages(from: Array(collected.prefix(30)))
        isLoading = false
    }

    // MARK: - Date parsing

    /// Converts a human-readable date string like "Summer 2023" or "March 2021" into a date range.
    private func parseDateRange(from dateString: String) -> (start: Date, end: Date)? {
        guard !dateString.isEmpty else { return nil }

        let lower = dateString.lowercased()
        let cal = Calendar.current

        // Extract a 4-digit year
        guard let yearRange = dateString.range(of: #"\b(19|20)\d{2}\b"#, options: .regularExpression),
              let year = Int(dateString[yearRange]) else { return nil }

        // Named seasons
        let seasonRanges: [String: (Int, Int)] = [
            "spring": (3, 5), "summer": (6, 8),
            "autumn": (9, 11), "fall": (9, 11), "winter": (12, 2)
        ]
        for (name, (startMonth, endMonth)) in seasonRanges where lower.contains(name) {
            let (sy, ey) = name == "winter" ? (year, year + 1) : (year, year)
            guard let start = cal.date(from: DateComponents(year: sy, month: startMonth, day: 1)),
                  let endMonth0 = cal.date(from: DateComponents(year: ey, month: endMonth, day: 1)),
                  let end = cal.date(byAdding: DateComponents(month: 1), to: endMonth0) else { return nil }
            return (start, end)
        }

        // Named months
        let months = ["january":1,"february":2,"march":3,"april":4,"may":5,"june":6,
                      "july":7,"august":8,"september":9,"october":10,"november":11,"december":12]
        for (name, month) in months where lower.contains(name) {
            guard let start = cal.date(from: DateComponents(year: year, month: month, day: 1)),
                  let end = cal.date(byAdding: DateComponents(month: 1), to: start) else { return nil }
            return (start, end)
        }

        // Just a year — return the whole year
        guard let start = cal.date(from: DateComponents(year: year, month: 1, day: 1)),
              let end = cal.date(from: DateComponents(year: year + 1, month: 1, day: 1)) else { return nil }
        return (start, end)
    }

    // MARK: - PHAsset fetch strategies

    private func fetchByDateRange(from start: Date, to end: Date, limit: Int = 30) -> [PHAsset] {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "mediaType = %d AND creationDate >= %@ AND creationDate < %@",
            PHAssetMediaType.image.rawValue, start as NSDate, end as NSDate
        )
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = limit

        var assets: [PHAsset] = []
        let result = PHAsset.fetchAssets(with: options)
        result.enumerateObjects { asset, _, _ in assets.append(asset) }
        return assets
    }

    private func fetchByAlbumKeywords(_ keywords: [String], limit: Int = 20) -> [PHAsset] {
        var results: [PHAsset] = []
        let fetchOpts = PHFetchOptions()
        fetchOpts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOpts.fetchLimit = limit

        for collectionType: PHAssetCollectionType in [.smartAlbum, .album] {
            let albums = PHAssetCollection.fetchAssetCollections(with: collectionType, subtype: .any, options: nil)
            albums.enumerateObjects { collection, _, _ in
                let name = collection.localizedTitle?.lowercased() ?? ""
                guard keywords.contains(where: { name.contains($0.lowercased()) }) else { return }
                let assets = PHAsset.fetchAssets(in: collection, options: fetchOpts)
                assets.enumerateObjects { asset, _, _ in
                    if asset.mediaType == .image &&
                       !results.contains(where: { $0.localIdentifier == asset.localIdentifier }) {
                        results.append(asset)
                    }
                }
            }
        }
        return Array(results.prefix(limit))
    }

    private func fetchByFilenameKeywords(_ keywords: [String], limit: Int = 20) -> [PHAsset] {
        // Build OR predicate matching filename against each keyword
        let predicates = keywords.map {
            NSPredicate(format: "filename CONTAINS[cd] %@", $0)
        }
        guard !predicates.isEmpty else { return [] }

        let options = PHFetchOptions()
        options.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = limit

        var assets: [PHAsset] = []
        let result = PHAsset.fetchAssets(with: options)
        result.enumerateObjects { asset, _, _ in
            if asset.mediaType == .image { assets.append(asset) }
        }
        return assets
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

    // MARK: - Keyword extraction

    private func searchKeywords(for memory: Memory) -> [String] {
        // Split title into significant words (3+ chars), plus category
        var words = memory.title
            .components(separatedBy: .whitespaces)
            .filter { $0.count >= 3 }
        words.append(memory.category.rawValue)
        return words
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
