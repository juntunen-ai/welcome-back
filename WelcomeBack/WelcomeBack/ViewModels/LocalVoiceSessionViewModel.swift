import Foundation
import SwiftUI
import Combine

// MARK: - LocalVoiceSessionViewModel

/// Bridges `LocalVoiceAIService` into `@Published` properties for SwiftUI.
/// Mirrors `LiveSessionViewModel` interface exactly.
@MainActor
final class LocalVoiceSessionViewModel: ObservableObject {

    @Published var sessionState: LiveSessionState = .idle
    @Published var errorMessage: String?
    @Published var useFallback: Bool = false

    private var service: LocalVoiceAIService?
    private var stateObserverTask: Task<Void, Never>?

    /// The LLM instance used by the session. After `endSession()`,
    /// the model stays loaded and can be reclaimed via `reclaimableLLM`.
    private var sessionLLM: LocalLLMService?

    /// After the session ends, this holds the still-loaded LLM for reuse.
    private(set) var reclaimableLLM: LocalLLMService?

    func beginSession(profile: UserProfile, preloadedLLM: LocalLLMService? = nil) {
        service = LocalVoiceAIService()
        sessionLLM = preloadedLLM
        reclaimableLLM = nil
        errorMessage = nil
        useFallback = false
        sessionState = .connecting

        guard let service else { return }

        stateObserverTask = Task { [weak self] in
            guard let self else { return }
            for await state in service.stateStream {
                self.sessionState = state
                if case .error(let msg) = state {
                    self.errorMessage = msg
                }
            }
        }

        Task { [weak self] in
            guard let self, let service = self.service else { return }
            do {
                try await service.startSession(profile: profile, preloadedLLM: preloadedLLM)
            } catch {
                #if DEBUG
                print("[LocalVoiceVM] Session failed: \(error)")
                #endif
                self.errorMessage = error.localizedDescription
                self.sessionState = .error(error.localizedDescription)
            }
        }
    }

    func endSession() {
        stateObserverTask?.cancel()
        stateObserverTask = nil
        service?.endSession()
        // Keep reference to the still-loaded LLM so it can be reclaimed
        if let llm = sessionLLM, llm.isLoaded {
            reclaimableLLM = llm
        }
        sessionLLM = nil
        service = nil
    }
}

// MARK: - VoiceSessionBridge

/// Wraps either a cloud (Gemini) or local (llama.cpp) voice session,
/// forwarding published properties so `ListeningView` works with both.
@MainActor
final class VoiceSessionBridge: ObservableObject {

    enum Mode { case cloud, local }

    @Published var sessionState: LiveSessionState = .idle
    @Published var useFallback: Bool = false
    @Published var errorMessage: String?

    let mode: Mode

    private var cloudVM: LiveSessionViewModel?
    private var localVM: LocalVoiceSessionViewModel?
    private var cancellables = Set<AnyCancellable>()

    /// Pre-loaded LLM to pass to the local session (avoids re-loading on mic tap).
    var preloadedLLM: LocalLLMService?

    init(mode: Mode) {
        self.mode = mode

        switch mode {
        case .cloud:
            let vm = LiveSessionViewModel()
            self.cloudVM = vm
            vm.$sessionState.assign(to: &$sessionState)
            vm.$useFallback.assign(to: &$useFallback)
            vm.$errorMessage.assign(to: &$errorMessage)

        case .local:
            let vm = LocalVoiceSessionViewModel()
            self.localVM = vm
            vm.$sessionState.assign(to: &$sessionState)
            vm.$useFallback.assign(to: &$useFallback)
            vm.$errorMessage.assign(to: &$errorMessage)
        }
    }

    func beginSession(profile: UserProfile) {
        cloudVM?.beginSession(profile: profile)
        localVM?.beginSession(profile: profile, preloadedLLM: preloadedLLM)
    }

    func endSession() {
        cloudVM?.endSession()
        localVM?.endSession()
    }

    /// Returns the still-loaded LLM after a local session ends, for reuse.
    var reclaimableLLM: LocalLLMService? {
        localVM?.reclaimableLLM
    }
}
