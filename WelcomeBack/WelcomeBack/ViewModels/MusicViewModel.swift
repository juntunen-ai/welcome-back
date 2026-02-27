import MusicKit
import SwiftUI

@MainActor
final class MusicViewModel: ObservableObject {

    // MARK: - Published State

    @Published var authorizationStatus: MusicAuthorization.Status = MusicAuthorization.currentStatus
    @Published var recentAlbums: [Album] = []
    @Published var isPlaying: Bool = false
    @Published var currentAlbum: Album? = nil
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    // MARK: - Init

    init() {
        if MusicAuthorization.currentStatus == .authorized {
            Task { await loadRecentlyPlayed() }
        }
        observePlaybackState()
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        let status = await MusicAuthorization.request()
        authorizationStatus = status
        if status == .authorized {
            await loadRecentlyPlayed()
        }
    }

    // MARK: - Load Content

    func loadRecentlyPlayed() async {
        isLoading = true
        errorMessage = nil
        do {
            // Try personal recommendations first (requires MusicKit entitlement)
            var albums: [Album] = []
            do {
                var request = MusicPersonalRecommendationsRequest()
                request.limit = 10
                let response = try await request.response()
                for recommendation in response.recommendations {
                    for item in recommendation.items {
                        if case .album(let album) = item {
                            albums.append(album)
                        }
                    }
                }
            } catch {
                // Recommendations unavailable — fall through to recently played
            }

            // Fallback: recently played albums
            if albums.isEmpty {
                let recentRequest = MusicRecentlyPlayedRequest<Album>()
                let recentResponse = try await recentRequest.response()
                albums = Array(recentResponse.items.prefix(10))
            }

            recentAlbums = albums
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Playback

    func play(album: Album) async {
        do {
            ApplicationMusicPlayer.shared.queue = [album]
            try await ApplicationMusicPlayer.shared.play()
            currentAlbum = album
        } catch {
            errorMessage = "Could not play \(album.title). Please check your Apple Music subscription."
        }
    }

    func togglePlayback() {
        if isPlaying {
            ApplicationMusicPlayer.shared.pause()
        } else {
            Task {
                do {
                    try await ApplicationMusicPlayer.shared.play()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    func pause() {
        ApplicationMusicPlayer.shared.pause()
    }

    // MARK: - Observe Player State

    private func observePlaybackState() {
        Task { @MainActor in
            while !Task.isCancelled {
                withObservationTracking {
                    let status = ApplicationMusicPlayer.shared.state.playbackStatus
                    self.isPlaying = (status == .playing)
                } onChange: {
                    // Re-runs the loop body on next iteration to pick up the new value
                }
                // Yield to avoid a tight spin loop — playback changes are infrequent
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }
}
