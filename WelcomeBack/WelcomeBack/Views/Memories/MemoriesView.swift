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
                albumList
            }
        }
    }

    // MARK: - Album list

    private var albumList: some View {
        ScrollView {
            VStack(spacing: 14) {
                ForEach(photoService.albums) { album in
                    NavigationLink(destination: AlbumCarouselView(album: album, service: photoService)) {
                        AlbumCardView(album: album)
                    }
                    .buttonStyle(.plain)
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
                        Image(systemName: "person.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.onSurface.opacity(0.15))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            // Gradient — covers the bottom third solidly so text is always legible
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.88), location: 0),
                    .init(color: .black.opacity(0.55), location: 0.40),
                    .init(color: .clear,               location: 0.70),
                ],
                startPoint: .bottom,
                endPoint: .top
            )

            // Text pinned to bottom
            VStack(alignment: .leading, spacing: 4) {
                Text(album.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .shadow(color: .black, radius: 4, y: 1)

                Text(album.subtitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.accentYellow)
                    .lineLimit(1)
                    .shadow(color: .black, radius: 4, y: 1)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(Color.white.opacity(0.1))
        )
        .task(id: album.id) {
            // Always load a high-quality cover — album.thumbnail is a low-res
            // placeholder from the background scan and appears blurry at full width.
            guard lazyThumbnail == nil,
                  !album.assetLocalIDs.isEmpty else { return }

            // Prefer a non-screenshot photo as the card cover.
            let result = PHAsset.fetchAssets(
                withLocalIdentifiers: album.assetLocalIDs, options: nil)
            guard result.count > 0 else { return }

            var assetsByID: [String: PHAsset] = [:]
            result.enumerateObjects { a, _, _ in assetsByID[a.localIdentifier] = a }

            let coverAsset = album.assetLocalIDs
                .compactMap { assetsByID[$0] }
                .first { !$0.mediaSubtypes.contains(.photoScreenshot) }
                ?? result.firstObject
            guard let asset = coverAsset else { return }

            let scale = UIScreen.main.scale
            let targetSize = CGSize(width: 800 * scale, height: 480 * scale)
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
