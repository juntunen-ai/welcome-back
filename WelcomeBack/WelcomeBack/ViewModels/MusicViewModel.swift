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

    // Memory Lane state
    @Published var memoryLaneIsPlaying: Bool = false
    @Published var memoryLaneTrackCount: Int = 0
    @Published var memoryLaneError: String? = nil

    private let player = MPMusicPlayerController.applicationMusicPlayer
    private var playbackObserver: NSObjectProtocol?
    private var nowPlayingObserver: NSObjectProtocol?

    // MARK: - Init

    init() {
        if MPMediaLibrary.authorizationStatus() == .authorized {
            Task { await loadLibraryTracks() }
            loadMemoryLaneInfo()
        }
        observePlaybackState()
    }

    deinit {
        player.endGeneratingPlaybackNotifications()
        if let observer = playbackObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = nowPlayingObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        let status = await MPMediaLibrary.requestAuthorization()
        authorizationStatus = status
        if status == .authorized {
            await loadLibraryTracks()
            loadMemoryLaneInfo()
        }
    }

    // MARK: - Load Library Tracks

    func loadLibraryTracks() async {
        isLoading = true
        errorMessage = nil

        let query = MPMediaQuery.songs()
        query.groupingType = .title

        if let items = query.items, !items.isEmpty {
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

    // MARK: - Memory Lane (Favourites playlist)

    /// Returns items from the first playlist whose name matches "Favourites" /
    /// "Favorites" / "Favorite Songs" / "Liked Songs" (case-insensitive).
    /// Falls back to the 50 most-played songs if no such playlist exists.
    private func favouriteItems() -> [MPMediaItem] {
        let favouriteNames = ["favourites", "favorites", "favorite songs",
                              "liked songs", "my favorites", "my favourites"]

        let playlistQuery = MPMediaQuery.playlists()
        if let playlists = playlistQuery.collections as? [MPMediaPlaylist] {
            for playlist in playlists {
                let name = (playlist.value(forProperty: MPMediaPlaylistPropertyName) as? String ?? "").lowercased()
                if favouriteNames.contains(name) {
                    let items = playlist.items
                    if !items.isEmpty { return items }
                }
            }
        }

        // Fallback: most-played songs from the full library
        let songQuery = MPMediaQuery.songs()
        let items = songQuery.items ?? []
        return items.sorted { ($0.playCount) > ($1.playCount) }
    }

    func loadMemoryLaneInfo() {
        let items = favouriteItems()
        memoryLaneTrackCount = items.count
    }

    func startMemoryLane() {
        let items = favouriteItems()
        guard !items.isEmpty else {
            memoryLaneError = "No favourites found. Add songs to a \"Favourites\" playlist in Apple Music."
            return
        }
        memoryLaneError = nil

        // Shuffle and queue the whole playlist
        let shuffled = items.shuffled()
        let collection = MPMediaItemCollection(items: shuffled)
        player.setQueue(with: collection)
        player.shuffleMode = .off   // already shuffled manually
        player.repeatMode = .all
        player.play()

        // Update current track display
        if let first = shuffled.first {
            currentTrack = MediaTrack(item: first)
        }
        memoryLaneIsPlaying = true
    }

    func stopMemoryLane() {
        player.stop()
        memoryLaneIsPlaying = false
        currentTrack = nil
    }

    // MARK: - Individual Track Playback

    func play(track: MediaTrack) {
        memoryLaneIsPlaying = false
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

    func skipForward() {
        player.skipToNextItem()
    }

    func skipBackward() {
        // If more than 3 seconds in, restart current track; otherwise skip to previous
        if player.currentPlaybackTime > 3 {
            player.skipToBeginning()
        } else {
            player.skipToPreviousItem()
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
                guard let self else { return }
                self.isPlaying = self.player.playbackState == .playing
                // If player stopped externally, clear Memory Lane state
                if self.player.playbackState == .stopped {
                    self.memoryLaneIsPlaying = false
                }
            }
        }

        // Track changes during Memory Lane playback
        nowPlayingObserver = NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerNowPlayingItemDidChange,
            object: player,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.memoryLaneIsPlaying, let item = self.player.nowPlayingItem {
                    self.currentTrack = MediaTrack(item: item)
                }
            }
        }

        isPlaying = player.playbackState == .playing
    }
}
