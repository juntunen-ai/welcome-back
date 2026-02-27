import MediaPlayer
import SwiftUI

struct MusicView: View {

    @EnvironmentObject private var appVM: AppViewModel
    @StateObject private var musicVM = MusicViewModel()

    private let trackColumns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.backgroundDark.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        aiRadioCard
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                        appleMusicSection
                            .padding(.horizontal, 16)

                        memoryMixesSection
                            .padding(.horizontal, 16)

                        Spacer(minLength: musicVM.currentTrack != nil ? 100 : 24)
                    }
                }

                // Now-playing bar slides up from bottom when music is active
                if let track = musicVM.currentTrack {
                    NowPlayingBar(track: track, isPlaying: musicVM.isPlaying) {
                        musicVM.togglePlayback()
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4), value: musicVM.currentTrack?.persistentID)
            .navigationTitle("Therapeutic Music")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { } label: {
                        Image(systemName: "text.badge.plus")
                            .foregroundColor(.onSurface)
                            .frame(width: 44, height: 44)
                            .background(Color.surfaceVariant)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }

    // MARK: - AI Radio Card

    private var aiRadioCard: some View {
        VStack(spacing: 16) {
            Circle()
                .fill(Color.accentYellow)
                .frame(width: 64, height: 64)
                .overlay(
                    Image(systemName: "wand.and.stars.inverse")
                        .font(.system(size: 28))
                        .foregroundColor(.black)
                )

            VStack(spacing: 6) {
                Text("AI Radio")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.onSurface)

                Text("Generating a playlist of your favourite hits from the 1960s to help trigger positive memories.")
                    .font(.system(size: 14))
                    .foregroundColor(.onSurface.opacity(0.6))
                    .multilineTextAlignment(.center)
            }

            Button {
                // Start therapy session (future)
            } label: {
                Label("Start Therapy Session", systemImage: "play.circle.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.accentYellow)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding(24)
        .background(Color.accentYellow.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(Color.accentYellow.opacity(0.2))
        )
    }

    // MARK: - Apple Music Section (state-driven)

    private var appleMusicSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Apple Music")

            switch musicVM.authorizationStatus {
            case .notDetermined:
                ConnectAppleMusicCard {
                    Task { await musicVM.requestAuthorization() }
                }
            case .denied, .restricted:
                AppleMusicDeniedCard()
            case .authorized:
                authorizedContent
            @unknown default:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private var authorizedContent: some View {
        if musicVM.isLoading {
            ProgressView("Loading your music\u{2026}")
                .tint(.accentYellow)
                .foregroundColor(.onSurface.opacity(0.6))
                .frame(maxWidth: .infinity, minHeight: 120)
        } else if let error = musicVM.errorMessage {
            Text(error)
                .font(.system(size: 14))
                .foregroundColor(.onSurface.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding()
        } else if musicVM.recentTracks.isEmpty {
            Text("No tracks found in your music library.")
                .font(.system(size: 14))
                .foregroundColor(.onSurface.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding()
        } else {
            LazyVGrid(columns: trackColumns, spacing: 12) {
                ForEach(musicVM.recentTracks, id: \.persistentID) { track in
                    TrackCard(
                        track: track,
                        isCurrentlyPlaying: musicVM.currentTrack?.persistentID == track.persistentID && musicVM.isPlaying
                    ) {
                        musicVM.play(track: track)
                    }
                }
            }
        }
    }

    // MARK: - Memory Mixes (cosmetic placeholder)

    private var memoryMixesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Memory Mixes")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MemoryMixCard(icon: "drop.fill",          iconColor: .blue,   title: "Summer Lake 1965", trackCount: 12)
                MemoryMixCard(icon: "birthday.cake.fill", iconColor: .orange, title: "Birthday Jams",    trackCount: 8)
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .bold))
            .tracking(2)
            .foregroundColor(.onSurface.opacity(0.4))
            .padding(.horizontal, 4)
    }
}

// MARK: - Connect Apple Music Card

struct ConnectAppleMusicCard: View {
    let onConnect: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 40))
                .foregroundColor(Color(red: 0.99, green: 0.24, blue: 0.27))

            VStack(spacing: 6) {
                Text("Connect Apple Music")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.onSurface)

                Text("Allow access to play your favourite songs from your music library.")
                    .font(.system(size: 13))
                    .foregroundColor(.onSurface.opacity(0.6))
                    .multilineTextAlignment(.center)
            }

            Button(action: onConnect) {
                Text("Allow Access")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.accentYellow)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(24)
        .background(Color.surfaceVariant.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(Color.white.opacity(0.05))
        )
    }
}

// MARK: - Denied / Restricted Card

struct AppleMusicDeniedCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .font(.system(size: 28))
                .foregroundColor(.onSurface.opacity(0.3))

            Text("Music library access was denied.\nPlease enable it in Settings \u{203A} Privacy \u{203A} Media & Apple Music.")
                .font(.system(size: 13))
                .foregroundColor(.onSurface.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.surfaceVariant.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Track Card

struct TrackCard: View {
    let track: MPMediaItem
    let isCurrentlyPlaying: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                artworkView
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(isCurrentlyPlaying ? Color.accentYellow : Color.clear, lineWidth: 2)
                    )
                    .overlay(alignment: .bottomTrailing) {
                        if isCurrentlyPlaying {
                            Image(systemName: "waveform")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.black)
                                .padding(5)
                                .background(Color.accentYellow)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                                .padding(6)
                        }
                    }

                Text(track.title ?? "Unknown")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.onSurface)
                    .lineLimit(1)

                Text(track.artist ?? "Unknown Artist")
                    .font(.system(size: 10))
                    .foregroundColor(.onSurface.opacity(0.5))
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var artworkView: some View {
        if let artwork = track.artwork,
           let image = artwork.image(at: CGSize(width: 200, height: 200)) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Rectangle()
                .fill(Color.surfaceVariant)
                .overlay(
                    Image(systemName: "music.note")
                        .foregroundColor(.onSurface.opacity(0.3))
                )
        }
    }
}

// MARK: - Now Playing Bar

struct NowPlayingBar: View {
    let track: MPMediaItem
    let isPlaying: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Artwork thumbnail
            Group {
                if let artwork = track.artwork,
                   let image = artwork.image(at: CGSize(width: 80, height: 80)) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.surfaceVariant
                        .overlay(
                            Image(systemName: "music.note")
                                .foregroundColor(.onSurface.opacity(0.3))
                        )
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title ?? "Unknown")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.onSurface)
                    .lineLimit(1)

                Text(track.artist ?? "Unknown Artist")
                    .font(.system(size: 11))
                    .foregroundColor(.onSurface.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onToggle) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.black)
                    .frame(width: 44, height: 44)
                    .background(Color.accentYellow)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.4), radius: 16, y: -4)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
}

// MARK: - Memory Mix Card

struct MemoryMixCard: View {

    let icon: String
    let iconColor: Color
    let title: String
    let trackCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: 16)
                .fill(iconColor.opacity(0.2))
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 36))
                        .foregroundColor(iconColor)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.onSurface)

                Text("\(trackCount) tracks")
                    .font(.system(size: 12))
                    .foregroundColor(.onSurface.opacity(0.5))
            }
        }
        .padding(16)
        .background(Color.surfaceVariant.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.white.opacity(0.05))
        )
    }
}

#Preview {
    MusicView()
        .environmentObject(AppViewModel())
}
