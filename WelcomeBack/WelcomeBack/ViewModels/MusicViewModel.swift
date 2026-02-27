import MediaPlayer
import SwiftUI

// MARK: - Track model (replaces MusicKit Track)

struct MediaTrack: Identifiable {
    let id: UInt64
    let title: String
    let artistName: String
    let artworkImage: UIImage?
    let mediaItem: MPMediaItem

    init(item: MPMediaItem) {
        self.id = item.persistentID
        self.title = item.title ?? "Unknown Title"
        self.artistName = item.artist ?? "Unknown Artist"
        self.artworkImage = item.artwork?.image(at: CGSize(width: 200, height: 200))
        self.mediaItem = item
    }
}

// MARK: - ViewModel

@MainActor
final class MusicViewModel: ObservableObject {

    @Published var authorizationStatus: MPMediaLibraryAuthorizationStatus = MPMediaLibrary.authorizationStatus()
    @Published var recentTracks: [MediaTrack] = []
    @Published var isPlaying: Bool = false
    @Published var currentTrack: MediaTrack? = nil
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private let player = MPMusicPlayerController.applicationMusicPlayer
    private var playbackObserver: NSObjectProtocol?

    // MARK: - Init

    init() {
        if MPMediaLibrary.authorizationStatus() == .authorized {
            Task { await loadLibraryTracks() }
        }
        observePlaybackState()
    }

    deinit {
        player.endGeneratingPlaybackNotifications()
        if let observer = playbackObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        let status = await MPMediaLibrary.requestAuthorization()
        authorizationStatus = status
        if status == .authorized {
            await loadLibraryTracks()
        }
    }

    // MARK: - Load Content

    func loadLibraryTracks() async {
        isLoading = true
        errorMessage = nil

        let query = MPMediaQuery.songs()
        query.groupingType = .title

        if let items = query.items, !items.isEmpty {
            // Sort by last played date, most recent first; fall back to title sort
            let sorted = items.sorted {
                let a = $0.lastPlayedDate ?? .distantPast
                let b = $1.lastPlayedDate ?? .distantPast
                return a > b
            }
            recentTracks = Array(sorted.prefix(50)).map { MediaTrack(item: $0) }
        } else {
            errorMessage = "No songs found in your library.\nAdd music to Apple Music and try again."
        }

        isLoading = false
    }

    // MARK: - Playback

    func play(track: MediaTrack) {
        let collection = MPMediaItemCollection(items: [track.mediaItem])
        player.setQueue(with: collection)
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
        player.beginGeneratingPlaybackNotifications()

        playbackObserver = NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: player,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isPlaying = self?.player.playbackState == .playing
            }
        }

        // Set initial state
        isPlaying = player.playbackState == .playing
    }
}
