import MusicKit
import MediaPlayer
import SwiftUI

@MainActor
final class MusicViewModel: ObservableObject {

    // MARK: - Published State

    @Published var authorizationStatus: MusicAuthorization.Status = MusicAuthorization.currentStatus
    @Published var recentTracks: [Track] = []
    @Published var isPlaying: Bool = false
    @Published var currentTrack: Track? = nil
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private var playbackObserver: NSObjectProtocol?

    // MARK: - Init

    init() {
        if MusicAuthorization.currentStatus == .authorized {
            Task { await loadRecentlyPlayed() }
        }
        observePlaybackState()
    }

    deinit {
        if let observer = playbackObserver {
            NotificationCenter.default.removeObserver(observer)
        }
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
        guard #available(iOS 16, *) else { return }
        isLoading = true
        errorMessage = nil
        do {
            var request = MusicRecentlyPlayedRequest<Track>()
            request.limit = 25
            let response = try await request.response()
            recentTracks = Array(response.items)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Playback

    func play(track: Track) async {
        do {
            ApplicationMusicPlayer.shared.queue = [track]
            try await ApplicationMusicPlayer.shared.play()
            currentTrack = track
        } catch {
            errorMessage = "Could not play \(track.title). Please check your Apple Music subscription."
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
        // Use NotificationCenter to observe playback state — available on iOS 15+
        playbackObserver = NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: MPMusicPlayerController.applicationMusicPlayer,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                let status = ApplicationMusicPlayer.shared.state.playbackStatus
                self?.isPlaying = (status == .playing)
            }
        }
        MPMusicPlayerController.applicationMusicPlayer.beginGeneratingPlaybackNotifications()

        // Set initial state
        let status = ApplicationMusicPlayer.shared.state.playbackStatus
        isPlaying = (status == .playing)
    }
}
