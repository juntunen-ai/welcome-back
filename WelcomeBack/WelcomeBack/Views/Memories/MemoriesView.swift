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
            .task { await photoService.requestAuthorizationAndLoad() }
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
            } else if photoService.moments.isEmpty {
                emptyState
            } else {
                ScrollView {
                    mosaicGrid
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    Text("End of Memories")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(2)
                        .foregroundColor(.onSurface.opacity(0.3))
                        .padding(.vertical, 24)
                }
            }
        }
    }

    // MARK: - Mosaic grid
    // Layout pattern (repeating every 4):
    //   [0] full-width hero (tall)
    //   [1] [2] side-by-side (medium)
    //   [3] full-width (shorter)

    private var mosaicGrid: some View {
        let items = photoService.moments
        return VStack(spacing: 12) {
            ForEach(Array(stride(from: 0, to: items.count, by: 4)), id: \.self) { base in
                if base < items.count {
                    NavigationLink(destination: MomentCarouselView(moment: items[base], service: photoService)) {
                        MomentTileView(moment: items[base], height: 220)
                    }
                    .buttonStyle(.plain)
                }

                let b1 = base + 1, b2 = base + 2
                if b1 < items.count {
                    HStack(spacing: 12) {
                        NavigationLink(destination: MomentCarouselView(moment: items[b1], service: photoService)) {
                            MomentTileView(moment: items[b1], height: 160)
                        }
                        .buttonStyle(.plain)

                        if b2 < items.count {
                            NavigationLink(destination: MomentCarouselView(moment: items[b2], service: photoService)) {
                                MomentTileView(moment: items[b2], height: 160)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Color.clear
                        }
                    }
                }

                let b3 = base + 3
                if b3 < items.count {
                    NavigationLink(destination: MomentCarouselView(moment: items[b3], service: photoService)) {
                        MomentTileView(moment: items[b3], height: 160)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
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
                Task { await photoService.requestAuthorizationAndLoad() }
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
                Text("No photos found")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.onSurface)
                Text("Your photo library appears to be empty.")
                    .font(.system(size: 14))
                    .foregroundColor(.onSurface.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
    }
}

// MARK: - Moment Tile

struct MomentTileView: View {

    let moment: PhotoMoment
    var height: CGFloat = 160

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Gradient overlay so text is always legible
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.75), location: 0),
                    .init(color: .black.opacity(0.45), location: 0.5),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .bottom,
                endPoint: .top
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(moment.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .shadow(color: .black.opacity(0.9), radius: 2, y: 1)

                Text(moment.subtitle.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1)
                    .foregroundColor(.accentYellow)
                    .shadow(color: .black.opacity(0.9), radius: 2, y: 1)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background {
            if let thumbnail = moment.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .clipped()
            } else {
                ZStack {
                    Color.surfaceVariant
                    Image(systemName: "photo")
                        .font(.system(size: 28))
                        .foregroundColor(.onSurface.opacity(0.2))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.white.opacity(0.05))
        )
    }
}

#Preview {
    MemoriesView()
        .environmentObject(AppViewModel())
}
