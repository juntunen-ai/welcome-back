import MediaPlayer
import SwiftUI

@MainActor
final class MusicViewModel: ObservableObject {

    // MARK: - Published State

    @Published var authorizationStatus: MPMediaLibraryAuthorizationStatus = MPMediaLibrary.authorizationStatus()
    @Published var recentTracks: [MPMediaItem] = []
    @Published var isPlaying: Bool = false
    @Published var currentTrack: MPMediaItem? = nil
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private let player = MPMusicPlayerController.applicationMusicPlayer

    // MARK: - Init

    init() {
        if MPMediaLibrary.authorizationStatus() == .authorized {
            loadRecentlyPlayed()
        }
        observePlaybackState()
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        let status = await withCheckedContinuation { continuation in
            MPMediaLibrary.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        authorizationStatus = status
        if status == .authorized {
            loadRecentlyPlayed()
        }
    }

    // MARK: - Load Content

    func loadRecentlyPlayed() {
        isLoading = true
        errorMessage = nil

        // Query all songs, sorted by last played date descending
        let query = MPMediaQuery.songs()
        query.addFilterPredicate(
            MPMediaPropertyPredicate(
                value: MPMediaType.music.rawValue,
                forProperty: MPMediaItemPropertyMediaType
            )
        )

        guard let items = query.items, !items.isEmpty else {
            // Fallback: show all songs if no recently played found
            let allQuery = MPMediaQuery.songs()
            recentTracks = Array((allQuery.items ?? []).prefix(30))
            isLoading = false
            return
        }

        // Sort by lastPlayedDate descending, take top 30
        let sorted = items
            .filter { $0.lastPlayedDate != nil }
            .sorted { ($0.lastPlayedDate ?? .distantPast) > ($1.lastPlayedDate ?? .distantPast) }

        recentTracks = Array((sorted.isEmpty ? items : sorted).prefix(30))
        isLoading = false
    }

    // MARK: - Playback

    func play(track: MPMediaItem) {
        player.setQueue(with: MPMediaItemCollection(items: [track]))
        player.play()
        currentTrack = track
    }

    func togglePlayback() {
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
    }

    func pause() {
        player.pause()
    }

    // MARK: - Observe Player State

    private func observePlaybackState() {
        NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: player,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isPlaying = self?.player.playbackState == .playing
            }
        }
        player.beginGeneratingPlaybackNotifications()
    }
}
