import SwiftUI
import Photos

struct MemoriesView: View {

    @EnvironmentObject private var appVM: AppViewModel
    @State private var navPath: [Memory] = []

    var body: some View {
        NavigationStack(path: $navPath) {
            ZStack {
                Color.backgroundDark.ignoresSafeArea()

                if appVM.memories.isEmpty {
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
            .navigationTitle("Memories")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        // Filter action (future)
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                            .foregroundColor(.onSurface)
                            .frame(width: 44, height: 44)
                            .background(Color.surfaceVariant)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            // Push to carousel via NavigationLink — no global state needed
            .navigationDestination(for: Memory.self) { memory in
                MemoryCarouselView(memory: memory)
            }
            // Request photo permission early so it never fires mid-navigation
            .task {
                _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            }
        }
    }

    // MARK: - Grid
    // Layout pattern (repeating every 4):
    //   [0] full-width hero (tall)
    //   [1] [2] side-by-side (medium)
    //   [3] full-width (short)

    private var mosaicGrid: some View {
        let items = appVM.memories
        return VStack(spacing: 12) {
            ForEach(Array(stride(from: 0, to: items.count, by: 4)), id: \.self) { base in
                // Row A: full-width hero
                if base < items.count {
                    MemoryTileView(memory: items[base], height: 220)
                        .onTapGesture { navPath.append(items[base]) }
                }
                // Row B: two side-by-side
                let b1 = base + 1, b2 = base + 2
                if b1 < items.count {
                    HStack(spacing: 12) {
                        MemoryTileView(memory: items[b1], height: 160)
                            .onTapGesture { navPath.append(items[b1]) }
                        if b2 < items.count {
                            MemoryTileView(memory: items[b2], height: 160)
                                .onTapGesture { navPath.append(items[b2]) }
                        } else {
                            Color.clear
                        }
                    }
                }
                // Row C: full-width shorter
                let b3 = base + 3
                if b3 < items.count {
                    MemoryTileView(memory: items[b3], height: 160)
                        .onTapGesture { navPath.append(items[b3]) }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 56))
                .foregroundColor(.onSurface.opacity(0.3))

            VStack(spacing: 6) {
                Text("No memories yet")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.onSurface)

                Text("Your memories will appear here once added")
                    .font(.system(size: 14))
                    .foregroundColor(.onSurface.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
    }
}

// MARK: - Memory Tile

struct MemoryTileView: View {

    let memory: Memory
    var height: CGFloat = 160

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Gradient — strong at bottom so text is always legible
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.75), location: 0),
                    .init(color: .black.opacity(0.45), location: 0.5),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .bottom,
                endPoint: .top
            )

            // Labels
            VStack(alignment: .leading, spacing: 2) {
                Text(memory.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .shadow(color: .black.opacity(0.9), radius: 2, y: 1)

                if !memory.date.isEmpty {
                    Text(memory.date.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1)
                        .foregroundColor(.accentYellow)
                        .shadow(color: .black.opacity(0.9), radius: 2, y: 1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background {
            // Image as background so it fills without disrupting ZStack alignment
            if let uiImage = UIImage(named: memory.imageURL) {
                Image(uiImage: uiImage)
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
