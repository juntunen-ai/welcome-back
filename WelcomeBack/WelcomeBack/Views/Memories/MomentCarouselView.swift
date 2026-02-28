import SwiftUI
import Photos

struct MomentCarouselView: View {

    let moment: PhotoMoment
    let service: PhotoLibraryService

    @State private var photos: [UIImage] = []
    @State private var currentIndex = 0
    @State private var isLoading = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isLoading {
                loadingView
            } else if photos.isEmpty {
                emptyView
            } else {
                carouselView
            }
        }
        .navigationTitle(moment.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            photos = await service.loadPhotos(for: moment)
            isLoading = false
        }
    }

    // MARK: - Carousel

    private var carouselView: some View {
        VStack(spacing: 0) {
            // Counter
            Text("\(currentIndex + 1) of \(photos.count)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .padding(.top, 16)
                .padding(.bottom, 12)

            // Swipeable pages
            TabView(selection: $currentIndex) {
                ForEach(photos.indices, id: \.self) { i in
                    Image(uiImage: photos[i])
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal, 16)
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(maxHeight: .infinity)

            // Dot indicators (cap at 20)
            if photos.count <= 20 {
                HStack(spacing: 6) {
                    ForEach(photos.indices, id: \.self) { i in
                        Circle()
                            .fill(i == currentIndex ? Color.accentYellow : Color.white.opacity(0.3))
                            .frame(width: i == currentIndex ? 8 : 6,
                                   height: i == currentIndex ? 8 : 6)
                            .animation(.spring(response: 0.3), value: currentIndex)
                    }
                }
                .padding(.bottom, 48)
                .padding(.top, 16)
            } else {
                Text("\(currentIndex + 1) / \(photos.count)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.bottom, 48)
                    .padding(.top, 16)
            }
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
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.3))
            Text("No photos found for this period.")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
}
