import SwiftUI

struct MemoriesView: View {

    @EnvironmentObject private var appVM: AppViewModel

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
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
        }
        .sheet(isPresented: $appVM.playbackSheetPresented, onDismiss: {
            appVM.selectedFamilyMember = nil
        }) {
            if let member = appVM.selectedFamilyMember {
                PlaybackView(member: member)
                    .environmentObject(appVM)
            }
        }
    }

    // MARK: - Mosaic Grid

    private var mosaicGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(Array(appVM.memories.enumerated()), id: \.element.id) { index, memory in
                MemoryTileView(memory: memory, isLarge: index == 0, isWide: index == 3)
                    .onTapGesture {
                        appVM.selectMemory(memory)
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
    let isLarge: Bool
    let isWide: Bool

    private var tileHeight: CGFloat {
        if isLarge { return 260 }
        if isWide  { return 120 }
        return 160
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background image or colour placeholder
            if let uiImage = UIImage(named: memory.imageURL) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.surfaceVariant
                    Image(systemName: "photo")
                        .font(.system(size: 28))
                        .foregroundColor(.onSurface.opacity(0.2))
                }
            }

            // Gradient overlay — always present so labels remain readable
            LinearGradient(
                colors: [.black.opacity(0.8), .clear],
                startPoint: .bottom,
                endPoint: .center
            )

            // Labels
            VStack(alignment: .leading, spacing: 2) {
                Text(memory.date.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
                    .foregroundColor(.accentYellow)

                Text(memory.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: tileHeight)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(Color.white.opacity(0.05))
        )
        .gridCellColumns(isLarge || isWide ? 2 : 1)
    }
}

#Preview {
    MemoriesView()
        .environmentObject(AppViewModel())
}
