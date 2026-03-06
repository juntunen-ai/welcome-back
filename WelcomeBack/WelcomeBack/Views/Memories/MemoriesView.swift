import SwiftUI
import Photos

struct MemoriesView: View {

    @EnvironmentObject private var appVM: AppViewModel
    @StateObject private var photoService = PhotoLibraryService()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundDark.ignoresSafeArea()
                content
            }
            .navigationTitle("Memories")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await photoService.requestAuthorizationAndLoad(
                    familyMembers: appVM.userProfile.familyMembers
                )
            }
        }
    }

    // MARK: - Content routing

    @ViewBuilder
    private var content: some View {
        switch photoService.authorizationStatus {
        case .notDetermined:
            permissionPromptView
        case .denied, .restricted:
            permissionDeniedView
        default:
            if photoService.isLoading {
                loadingView
            } else if photoService.albums.isEmpty && !photoService.isScanningInBackground {
                emptyState
            } else {
                albumSections
            }
        }
    }

    // MARK: - Section layout

    private var albumSections: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {

                if photoService.isScanningInBackground {
                    scanningBanner
                        .padding(.horizontal, 16)
                }

                ForEach(AlbumSection.allCases) { section in
                    let sectionAlbums = albums(for: section)
                    if !sectionAlbums.isEmpty {
                        albumSection(title: section.title,
                                     icon: section.icon,
                                     albums: sectionAlbums)
                    }
                }

                Text("End of Memories")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2)
                    .foregroundColor(.onSurface.opacity(0.3))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            }
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Section helpers

    private enum AlbumSection: String, CaseIterable, Identifiable {
        case family   = "Family"
        case trips    = "Trips"
        case holidays = "Holidays"
        case moments  = "Moments"

        var id: String { rawValue }

        var title: String { rawValue }

        var icon: String {
            switch self {
            case .family:   return "person.2.fill"
            case .trips:    return "airplane"
            case .holidays: return "star.fill"
            case .moments:  return "sparkles"
            }
        }
    }

    private func albums(for section: AlbumSection) -> [MemoryAlbum] {
        photoService.albums.filter { album in
            switch (section, album.theme) {
            case (.family,   .person):  return true
            case (.trips,    .trip):    return true
            case (.holidays, .holiday): return true
            case (.moments,  .scene):   return true
            default: return false
            }
        }
    }

    // MARK: - Section view

    private func albumSection(title: String, icon: String, albums: [MemoryAlbum]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.accentYellow)
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.5)
                    .foregroundColor(.onSurface.opacity(0.5))
            }
            .padding(.horizontal, 16)

            // Horizontal scroll of album cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(albums) { album in
                        NavigationLink(destination: AlbumCarouselView(album: album, service: photoService)) {
                            AlbumCardView(album: album)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Scanning banner

    private var scanningBanner: some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(.accentYellow)
                .scaleEffect(0.8)
            Text("Scanning for faces and scenes…")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.onSurface.opacity(0.6))
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.surfaceVariant.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - State views

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.accentYellow)
                .scaleEffect(1.4)
            Text("Loading memories…")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.onSurface.opacity(0.6))
        }
    }

    private var permissionPromptView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 56))
                .foregroundColor(.accentYellow.opacity(0.8))

            VStack(spacing: 8) {
                Text("Your Photo Memories")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.onSurface)
                Text("Allow access to your photos so memories from important moments in your life can be shown here.")
                    .font(.system(size: 14))
                    .foregroundColor(.onSurface.opacity(0.6))
                    .multilineTextAlignment(.center)
            }

            Button {
                Task {
                    await photoService.requestAuthorizationAndLoad(
                        familyMembers: appVM.userProfile.familyMembers
                    )
                }
            } label: {
                Text("Allow Photo Access")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.backgroundDark)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentYellow)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 32)
        }
        .padding(40)
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.slash")
                .font(.system(size: 48))
                .foregroundColor(.onSurface.opacity(0.3))

            VStack(spacing: 6) {
                Text("Photo access denied")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.onSurface)
                Text("Go to Settings → Privacy & Security → Photos → Welcome Back and allow access.")
                    .font(.system(size: 14))
                    .foregroundColor(.onSurface.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 56))
                .foregroundColor(.onSurface.opacity(0.3))

            VStack(spacing: 6) {
                Text("No memories yet")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.onSurface)
                Text("Photos will be organised by people, trips, and special moments.")
                    .font(.system(size: 14))
                    .foregroundColor(.onSurface.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
    }
}

// MARK: - Album Card

struct AlbumCardView: View {

    let album: MemoryAlbum
    @State private var lazyThumbnail: UIImage? = nil

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background thumbnail
            Group {
                if let thumbnail = lazyThumbnail ?? album.thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Color.surfaceVariant
                        Image(systemName: album.theme.sectionIcon)
                            .font(.system(size: 32))
                            .foregroundColor(.onSurface.opacity(0.2))
                    }
                }
            }
            .clipped()

            // Gradient overlay
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.8), location: 0),
                    .init(color: .black.opacity(0.3), location: 0.55),
                    .init(color: .clear,              location: 1),
                ],
                startPoint: .bottom,
                endPoint: .top
            )

            // Text
            VStack(alignment: .leading, spacing: 3) {
                Text(album.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .shadow(color: .black.opacity(0.8), radius: 2, y: 1)

                Text(album.subtitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.accentYellow)
                    .lineLimit(1)
                    .shadow(color: .black.opacity(0.8), radius: 2, y: 1)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(width: 160, height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.white.opacity(0.08))
        )
        .task(id: album.id) {
            guard lazyThumbnail == nil, album.thumbnail == nil,
                  let firstID = album.assetLocalIDs.first else { return }
            let result = PHAsset.fetchAssets(withLocalIdentifiers: [firstID], options: nil)
            guard let asset = result.firstObject else { return }
            let opts = PHImageRequestOptions()
            opts.deliveryMode = .fastFormat
            opts.isSynchronous = false
            opts.isNetworkAccessAllowed = false
            lazyThumbnail = await withCheckedContinuation { cont in
                nonisolated(unsafe) var resumed = false
                PHImageManager.default().requestImage(
                    for: asset, targetSize: CGSize(width: 400, height: 400),
                    contentMode: .aspectFill, options: opts
                ) { img, _ in
                    guard !resumed else { return }
                    resumed = true
                    cont.resume(returning: img)
                }
            }
        }
        .accessibilityLabel("\(album.title), \(album.subtitle)")
    }
}

#Preview {
    MemoriesView()
        .environmentObject(AppViewModel())
}
