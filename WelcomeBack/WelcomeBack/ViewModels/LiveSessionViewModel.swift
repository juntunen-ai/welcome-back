import Foundation
import SwiftUI

// MARK: - LiveSessionViewModel

/// Bridges `GeminiLiveService`'s actor-isolated `AsyncStream` into
/// `@Published` properties that SwiftUI views can bind to.
@MainActor
final class LiveSessionViewModel: ObservableObject {

    // MARK: - Published state

    @Published var sessionState: LiveSessionState = .idle
    @Published var errorMessage: String?
    /// Set to `true` when the Live connection fails — `ListeningView`
    /// observes this and falls back to the legacy REST + PlaybackView path.
    @Published var useFallback: Bool = false

    // MARK: - Private

    private let service = GeminiLiveService.shared
    private var stateObserverTask: Task<Void, Never>?

    // MARK: - Session Lifecycle

    /// Opens a Gemini Live session for the given user profile.
    /// On connection failure, sets `useFallback = true` so the caller
    /// can gracefully revert to the REST path.
    func beginSession(profile: UserProfile) {
        errorMessage = nil
        useFallback = false
        sessionState = .connecting

        // Subscribe to state stream from the actor
        stateObserverTask = Task { [weak self] in
            guard let self else { return }
            for await state in await self.service.stateStream {
                self.sessionState = state
                if case .error(let msg) = state {
                    self.errorMessage = msg
                }
            }
        }

        // Start the session
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.service.startSession(profile: profile)
            } catch LiveServiceError.apiKeyMissing {
                self.useFallback = true
            } catch {
                // Any connection/setup failure — fall back to REST
                self.useFallback = true
            }
        }
    }

    /// Closes the WebSocket session and tears down audio.
    func endSession() {
        stateObserverTask?.cancel()
        stateObserverTask = nil
        Task { await service.endSession() }
    }
}
