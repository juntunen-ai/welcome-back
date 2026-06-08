import Foundation
import SwiftUI

// MARK: - LiveSessionViewModel

/// Bridges `GeminiLiveService` into `@Published` properties for SwiftUI.
/// Creates a fresh `GeminiLiveService` for every session so the AsyncStream
/// and audio engine are always in a clean state.
@MainActor
final class LiveSessionViewModel: ObservableObject {

    // MARK: - Published state

    @Published var sessionState: LiveSessionState = .idle
    @Published var errorMessage: String?
    /// True when Live WebSocket fails — ListeningView falls back to REST path.
    @Published var useFallback: Bool = false

    // MARK: - Private

    /// A new service instance is created each time beginSession() is called.
    private var service: GeminiLiveService?
    private var stateObserverTask: Task<Void, Never>?

    // MARK: - Session Lifecycle

    func beginSession(profile: UserProfile) {
        // Always start with a fresh service so the stream is clean
        service = GeminiLiveService()
        errorMessage = nil
        useFallback = false
        sessionState = .connecting

        guard let service else { return }

        // Subscribe to state stream
        stateObserverTask = Task { [weak self] in
            guard let self else { return }
            for await state in service.stateStream {
                self.sessionState = state
                if case .error(let msg) = state {
                    self.errorMessage = msg
                }
            }
        }

        // Start the session
        Task { [weak self] in
            guard let self, let service = self.service else { return }
            do {
                try await service.startSession(profile: profile)
            } catch {
                // Any failure → fall back to REST + PlaybackView
                self.useFallback = true
            }
        }
    }

    func endSession() {
        stateObserverTask?.cancel()
        stateObserverTask = nil
        service?.endSession()
        service = nil
    }
}
