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
            if photoService.isLoading || photoService.isScanningInBackground {
                loadingView
            } else if appVM.userProfile.familyMembers.isEmpty {
                noFamilyMembersView
            } else if photoService.albums.isEmpty {
                emptyState
            } else {
                albumGrid
            }
        }
    }

    // MARK: - Alternating grid  (full-width → pair → full-width → pair …)

    /// Albums grouped into display rows.
    /// Even-index rows get one full-width card; odd-index rows get up to two half-width cards.
    private var gridRows: [[MemoryAlbum]] {
        var rows: [[MemoryAlbum]] = []
        var i = 0
        var fullWidth = true
        let albums = photoService.albums
        while i < albums.count {
            if fullWidth {
                rows.append([albums[i]])
                i += 1
            } else {
                let end = min(i + 2, albums.count)
                rows.append(Array(albums[i..<end]))
                i = end
            }
            fullWidth.toggle()
        }
        return rows
    }

    private var albumGrid: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(gridRows.indices, id: \.self) { rowIndex in
                    let row = gridRows[rowIndex]
                    if row.count == 1 {
                        albumTile(row[0], height: 300)
                    } else {
                        HStack(spacing: 12) {
                            ForEach(row) { album in
                                albumTile(album, height: 210)
                            }
                        }
                    }
                }

                Text("End of Memories")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2)
                    .foregroundColor(.onSurface.opacity(0.3))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
    }

    private func albumTile(_ album: MemoryAlbum, height: CGFloat) -> some View {
        NavigationLink(destination: AlbumCarouselView(album: album, service: photoService)) {
            AlbumCardView(album: album, height: height)
        }
        .buttonStyle(.plain)
    }

    // MARK: - State views

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.accentYellow)
                .scaleEffect(1.4)
            Text("Scanning photos for family members…")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.onSurface.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private var noFamilyMembersView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 56))
                .foregroundColor(.accentYellow.opacity(0.8))

            VStack(spacing: 8) {
                Text("No family members added")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.onSurface)
                Text("Add family members in the Family tab so their photos can appear here.")
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
                Text("No photos found")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.onSurface)
                Text("No photos of your family members were detected in your library yet.")
                    .font(.system(size: 14))
                    .foregroundColor(.onSurface.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
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
                Text("Allow access to your photos so memories of your family members can be shown here.")
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
}

// MARK: - Album Card

struct AlbumCardView: View {

    let album: MemoryAlbum
    let height: CGFloat
    @State private var lazyThumbnail: UIImage? = nil

    init(album: MemoryAlbum, height: CGFloat = 300) {
        self.album = album
        self.height = height
    }

    private var isLarge: Bool { height >= 260 }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Photo
            Group {
                if let img = lazyThumbnail ?? album.thumbnail {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Color.surfaceVariant
                        Image(systemName: "person.fill")
                            .font(.system(size: isLarge ? 52 : 36))
                            .foregroundColor(.onSurface.opacity(0.15))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            // Gradient
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.85), location: 0),
                    .init(color: .black.opacity(0.40), location: 0.45),
                    .init(color: .clear,               location: 0.72),
                ],
                startPoint: .bottom,
                endPoint: .top
            )

            // Text
            VStack(alignment: .leading, spacing: 3) {
                Text(album.title)
                    .font(.system(size: isLarge ? 20 : 15, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .shadow(color: .black.opacity(0.8), radius: 3, y: 1)

                if !album.subtitle.isEmpty {
                    Text(album.subtitle.uppercased())
                        .font(.system(size: isLarge ? 11 : 10, weight: .bold))
                        .tracking(1.5)
                        .foregroundColor(.accentYellow)
                        .lineLimit(1)
                        .shadow(color: .black.opacity(0.8), radius: 3, y: 1)
                }
            }
            .padding(.horizontal, isLarge ? 18 : 14)
            .padding(.bottom, isLarge ? 18 : 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.white.opacity(0.08))
        )
        .task(id: album.id) {
            guard lazyThumbnail == nil, !album.assetLocalIDs.isEmpty else { return }

            let result = PHAsset.fetchAssets(
                withLocalIdentifiers: album.assetLocalIDs, options: nil)
            guard result.count > 0 else { return }

            var byID: [String: PHAsset] = [:]
            result.enumerateObjects { a, _, _ in byID[a.localIdentifier] = a }

            let cover = album.assetLocalIDs
                .compactMap { byID[$0] }
                .first { !$0.mediaSubtypes.contains(.photoScreenshot) }
                ?? result.firstObject
            guard let asset = cover else { return }

            let scale = UIScreen.main.scale
            let targetSize = CGSize(width: 800 * scale, height: CGFloat(height) * scale * 1.2)
            let opts = PHImageRequestOptions()
            opts.deliveryMode = .highQualityFormat
            opts.isSynchronous = false
            opts.isNetworkAccessAllowed = false

            lazyThumbnail = await withCheckedContinuation { cont in
                nonisolated(unsafe) var resumed = false
                PHImageManager.default().requestImage(
                    for: asset, targetSize: targetSize,
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
