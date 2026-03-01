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
            .animation(.spring(response: 0.4), value: musicVM.currentTrack?.id)
            .navigationTitle("Memory Lane")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Memory Lane Card

    private var aiRadioCard: some View {
        VStack(spacing: 20) {
            // Icon — animated when playing
            ZStack {
                Circle()
                    .fill(musicVM.memoryLaneIsPlaying ? Color.accentYellow : Color.accentYellow.opacity(0.15))
                    .frame(width: 72, height: 72)

                Image(systemName: musicVM.memoryLaneIsPlaying ? "waveform" : "music.note.house.fill")
                    .font(.system(size: 30))
                    .foregroundColor(musicVM.memoryLaneIsPlaying ? .black : .accentYellow)
                    .symbolEffect(.variableColor.iterative, isActive: musicVM.memoryLaneIsPlaying)
            }

            // Inspirational copy
            VStack(spacing: 4) {
                Text(appVM.userProfile.name.isEmpty ? "Your songs" : appVM.userProfile.name)
                    .font(.system(size: 32, weight: .black))
                    .foregroundColor(.white)

                Text("these are your favorite songs.\nListen to them to remember who you are.")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color.accentYellow.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            // Now-playing info / error
            if let error = musicVM.memoryLaneError {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundColor(.red.opacity(0.8))
                    .multilineTextAlignment(.center)
            } else if musicVM.memoryLaneIsPlaying, let track = musicVM.currentTrack {
                VStack(spacing: 2) {
                    Text("Now playing")
                        .font(.system(size: 12))
                        .foregroundColor(.onSurface.opacity(0.5))
                    Text(track.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.accentYellow)
                        .lineLimit(1)
                    Text(track.artistName)
                        .font(.system(size: 12))
                        .foregroundColor(.onSurface.opacity(0.6))
                        .lineLimit(1)
                }
            }

            // Playback controls: skip back | play/stop | skip forward
            HStack(spacing: 24) {
                // Skip back
                Button {
                    musicVM.skipBackward()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 26))
                        .foregroundColor(musicVM.memoryLaneIsPlaying ? .onSurface : .onSurface.opacity(0.3))
                        .frame(width: 56, height: 56)
                        .background(Color.surfaceVariant.opacity(0.5))
                        .clipShape(Circle())
                }
                .disabled(!musicVM.memoryLaneIsPlaying)
                .buttonStyle(.plain)

                // Play / Stop
                Button {
                    if musicVM.memoryLaneIsPlaying {
                        musicVM.stopMemoryLane()
                    } else {
                        musicVM.startMemoryLane()
                    }
                } label: {
                    Image(systemName: musicVM.memoryLaneIsPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.black)
                        .frame(width: 72, height: 72)
                        .background(musicVM.memoryLaneIsPlaying ? Color.red.opacity(0.85) : Color.accentYellow)
                        .clipShape(Circle())
                        .shadow(color: Color.accentYellow.opacity(0.3), radius: 10, y: 4)
                }
                .disabled(musicVM.authorizationStatus != .authorized)
                .buttonStyle(.plain)

                // Skip forward
                Button {
                    musicVM.skipForward()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 26))
                        .foregroundColor(musicVM.memoryLaneIsPlaying ? .onSurface : .onSurface.opacity(0.3))
                        .frame(width: 56, height: 56)
                        .background(Color.surfaceVariant.opacity(0.5))
                        .clipShape(Circle())
                }
                .disabled(!musicVM.memoryLaneIsPlaying)
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .background(Color.accentYellow.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(
                    musicVM.memoryLaneIsPlaying ? Color.accentYellow.opacity(0.5) : Color.accentYellow.opacity(0.2)
                )
        )
        .animation(.easeInOut(duration: 0.3), value: musicVM.memoryLaneIsPlaying)
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
            Text("No songs found in your library.\nAdd music to Apple Music and come back.")
                .font(.system(size: 14))
                .foregroundColor(.onSurface.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding()
        } else {
            LazyVGrid(columns: trackColumns, spacing: 12) {
                ForEach(musicVM.recentTracks) { track in
                    TrackCard(
                        track: track,
                        isCurrentlyPlaying: musicVM.currentTrack?.id == track.id && musicVM.isPlaying
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

                Text("Allow access to play your favourite songs from your Apple Music library.")
                    .font(.system(size: 13))
                    .foregroundColor(.onSurface.opacity(0.6))
                    .multilineTextAlignment(.center)
            }

            Button(action: onConnect) {
                Text("Connect")
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

            Text("Apple Music access was denied.\nPlease enable it in Settings \u{203A} Privacy \u{203A} Media & Apple Music.")
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
    let track: MediaTrack
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

                Text(track.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.onSurface)
                    .lineLimit(1)

                Text(track.artistName)
                    .font(.system(size: 10))
                    .foregroundColor(.onSurface.opacity(0.5))
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var artworkView: some View {
        if let image = track.artworkImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            artworkPlaceholder
        }
    }

    private var artworkPlaceholder: some View {
        Rectangle()
            .fill(Color.surfaceVariant)
            .overlay(
                Image(systemName: "music.note")
                    .foregroundColor(.onSurface.opacity(0.3))
            )
    }
}

// MARK: - Now Playing Bar

struct NowPlayingBar: View {
    let track: MediaTrack
    let isPlaying: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let image = track.artworkImage {
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
                Text(track.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.onSurface)
                    .lineLimit(1)

                Text(track.artistName)
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
