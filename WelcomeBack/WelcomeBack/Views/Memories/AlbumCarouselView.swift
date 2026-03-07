import SwiftUI
import CoreLocation

struct AlbumCarouselView: View {

    let album: MemoryAlbum
    let service: PhotoLibraryService

    @State private var photoItems: [PhotoItem] = []
    @State private var currentIndex = 0
    @State private var isLoading = true
    @State private var locationCache: [String: String] = [:]

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .none
        return f
    }()

    // Always use the most up-to-date version of this album from the service.
    private var currentAlbum: MemoryAlbum {
        service.albums.first(where: { $0.id == album.id }) ?? album
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isLoading {
                loadingView
            } else if photoItems.isEmpty {
                emptyView
            } else {
                carouselView
            }
        }
        .navigationTitle(album.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await loadPhotos()
        }
        // Re-load when the background scan finishes (isScanningInBackground → false).
        // Using isScanningInBackground instead of albums avoids requiring MemoryAlbum: Equatable.
        .onChange(of: service.isScanningInBackground) { _, isScanning in
            guard !isScanning, photoItems.isEmpty else { return }
            Task { await loadPhotos() }
        }
    }

    // MARK: - Photo loading

    private func loadPhotos() async {
        let latest = currentAlbum
        guard !latest.assetLocalIDs.isEmpty else {
            isLoading = false
            return
        }
        isLoading = true
        photoItems = await service.loadPhotos(for: latest)
        isLoading = false
        currentIndex = 0
        geocodeIfNeeded(at: 0)
        geocodeIfNeeded(at: 1)
    }

    // MARK: - Carousel

    private var carouselView: some View {
        VStack(spacing: 0) {
            // Counter
            Text("\(currentIndex + 1) of \(photoItems.count)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .padding(.top, 16)
                .padding(.bottom, 12)

            // Swipeable pages
            TabView(selection: $currentIndex) {
                ForEach(photoItems.indices, id: \.self) { i in
                    photoPage(photoItems[i])
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(maxHeight: .infinity)
            .onChange(of: currentIndex) { _, newIndex in
                geocodeIfNeeded(at: newIndex)
                geocodeIfNeeded(at: newIndex + 1)
            }

            // Dot indicators
            HStack(spacing: 6) {
                ForEach(photoItems.indices, id: \.self) { i in
                    Circle()
                        .fill(i == currentIndex ? Color.accentYellow : Color.white.opacity(0.3))
                        .frame(width: i == currentIndex ? 8 : 6,
                               height: i == currentIndex ? 8 : 6)
                        .animation(.spring(response: 0.3), value: currentIndex)
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 48)
        }
    }

    // MARK: - Photo page

    private func photoPage(_ item: PhotoItem) -> some View {
        VStack(spacing: 16) {
            Image(uiImage: item.image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 16)

            metadataRow(item)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func metadataRow(_ item: PhotoItem) -> some View {
        let locationName = locationCache[item.id].flatMap {
            $0.isEmpty || $0 == "—" ? nil : $0
        }
        if locationName != nil || item.date != nil {
            VStack(alignment: .leading, spacing: 6) {
                if let loc = locationName {
                    Label(loc, systemImage: "mappin.and.ellipse")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                if let date = item.date {
                    Label(Self.dateFormatter.string(from: date), systemImage: "calendar")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Geocoding

    private func geocodeIfNeeded(at index: Int) {
        guard index >= 0, index < photoItems.count else { return }
        let item = photoItems[index]
        guard locationCache[item.id] == nil, let location = item.location else { return }
        locationCache[item.id] = ""
        Task {
            guard let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first else {
                locationCache[item.id] = "—"
                return
            }
            let city    = placemark.locality ?? placemark.administrativeArea ?? ""
            let country = placemark.country ?? ""
            let name    = [city, country].filter { !$0.isEmpty }.joined(separator: ", ")
            locationCache[item.id] = name.isEmpty ? "—" : name
        }
    }

    // MARK: - State views

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.accentYellow)
                .scaleEffect(1.4)
            Text("Loading photos…")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
    }

    private var emptyView: some View {
        VStack(spacing: 20) {
            if service.isScanningInBackground {
                ProgressView()
                    .tint(.accentYellow)
                    .scaleEffect(1.2)
                Text("Scanning your photo library for photos of \(album.title)…")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Text("This may take a moment.")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.35))
            } else {
                Image(systemName: "person.fill.questionmark")
                    .font(.system(size: 48))
                    .foregroundColor(.white.opacity(0.25))
                Text("No photos of \(album.title) found in your library.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
    }
}
