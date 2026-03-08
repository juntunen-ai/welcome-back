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
            // Show the grid whenever there is something to show —
            // either family members (for photo albums) or saved memory stories.
            if appVM.userProfile.familyMembers.isEmpty && appVM.userProfile.memories.isEmpty {
                noFamilyMembersView
            } else {
                albumGrid   // Always show tiles — scan runs in background
            }
        }
    }

    // MARK: - Alternating grid (full → pair → full → pair …)

    private var gridRows: [[MemoryAlbum]] {
        var rows: [[MemoryAlbum]] = []
        let items = photoService.albums
        var i = 0
        while i < items.count {
            // Full-width row
            rows.append([items[i]]); i += 1
            guard i < items.count else { break }
            // Pair row
            if i + 1 < items.count {
                rows.append([items[i], items[i + 1]]); i += 2
            } else {
                rows.append([items[i]]); i += 1
            }
        }
        return rows
    }

    private var albumGrid: some View {
        GeometryReader { proxy in
            let hPad: CGFloat = 16
            let gap:  CGFloat = 12
            let total = proxy.size.width - hPad * 2
            let half  = (total - gap) / 2

            ScrollView {
                VStack(spacing: gap) {

                    // Small scanning indicator — doesn't block the tiles
                    if photoService.isScanningInBackground {
                        HStack(spacing: 8) {
                            ProgressView().tint(.accentYellow).scaleEffect(0.75)
                            Text("Scanning for photos…")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.onSurface.opacity(0.5))
                            Spacer()
                        }
                        .padding(.horizontal, 6)
                    }

                    ForEach(gridRows.indices, id: \.self) { i in
                        let row = gridRows[i]
                        if row.count == 1 {
                            tile(row[0], width: total, height: 300)
                        } else {
                            HStack(spacing: gap) {
                                ForEach(row) { album in
                                    tile(album, width: half, height: 220)
                                }
                            }
                        }
                    }

                    if !photoService.albums.isEmpty {
                        Text("End of Memories")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(2)
                            .foregroundColor(.onSurface.opacity(0.3))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    }

                    // ── Personal memory stories (UserProfile.memories) ─────────────
                    if !appVM.userProfile.memories.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("YOUR STORIES")
                                .font(.system(size: 12, weight: .bold))
                                .tracking(1.5)
                                .foregroundColor(.accentYellow)
                                .padding(.horizontal, 6)

                            ForEach(appVM.userProfile.memories) { memory in
                                MemoryStoryCard(memory: memory)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
                .padding(.horizontal, hPad)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
    }

    private func tile(_ album: MemoryAlbum, width: CGFloat, height: CGFloat) -> some View {
        NavigationLink(destination: AlbumCarouselView(album: album, service: photoService)) {
            AlbumCardView(album: album, width: width, height: height)
        }
        .buttonStyle(.plain)
    }

    // MARK: - State views

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
    let width: CGFloat
    let height: CGFloat
    @State private var lazyThumbnail: UIImage? = nil

    init(album: MemoryAlbum, width: CGFloat = 300, height: CGFloat = 300) {
        self.album = album
        self.width = width
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
            .frame(width: width, height: height)
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
            .padding(.horizontal, isLarge ? 18 : 13)
            .padding(.bottom,    isLarge ? 18 : 13)
        }
        .frame(width: width, height: height)
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
            let targetSize = CGSize(width: width * scale, height: height * scale)
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

// MARK: - Memory Story Card

/// Displays a single `Memory` (title, date, description) from `UserProfile.memories`
/// as a photo-card-style horizontal-scroll tile with a category gradient background.
struct MemoryStoryCard: View {

    let memory: Memory

    private var categoryColor: Color {
        switch memory.category {
        case .family:  return Color(red: 0.20, green: 0.40, blue: 0.85)   // rich blue
        case .events:  return Color(red: 0.85, green: 0.45, blue: 0.10)   // warm orange
        case .places:  return Color(red: 0.15, green: 0.60, blue: 0.35)   // forest green
        case .other:   return Color(red: 0.45, green: 0.35, blue: 0.70)   // muted purple
        }
    }

    private var categoryIcon: String {
        switch memory.category {
        case .family:  return "heart.fill"
        case .events:  return "sparkles"
        case .places:  return "map.fill"
        case .other:   return "doc.text.fill"
        }
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {

            // ── Background: colour gradient ─────────────────────────────────
            LinearGradient(
                colors: [categoryColor, categoryColor.opacity(0.55)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // ── Decorative large icon (watermark style) ─────────────────────
            Image(systemName: categoryIcon)
                .font(.system(size: 90, weight: .black))
                .foregroundColor(.white.opacity(0.12))
                .rotationEffect(.degrees(-10))
                .offset(x: 70, y: -30)
                .allowsHitTesting(false)

            // ── Dark scrim so text is legible ───────────────────────────────
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.75), location: 0),
                    .init(color: .black.opacity(0.30), location: 0.55),
                    .init(color: .clear,               location: 0.80)
                ],
                startPoint: .bottom,
                endPoint: .top
            )

            // ── Text content ────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 4) {
                if !memory.date.isEmpty {
                    Text(memory.date.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundColor(.white.opacity(0.65))
                        .lineLimit(1)
                }

                Text(memory.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .shadow(color: .black.opacity(0.6), radius: 3, y: 1)

                Text(memory.description)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.80))
                    .lineLimit(3)
                    .shadow(color: .black.opacity(0.5), radius: 2)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.white.opacity(0.12))
        )
        .shadow(color: categoryColor.opacity(0.35), radius: 8, y: 4)
        .accessibilityLabel("\(memory.title), \(memory.date)")
    }
}

#Preview {
    MemoriesView()
        .environmentObject(AppViewModel())
}
