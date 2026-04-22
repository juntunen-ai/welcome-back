import Foundation
import SwiftUI

@MainActor
final class AppViewModel: ObservableObject {

    // MARK: - Navigation

    @Published var selectedTab: AppTab = .home
    @Published var listeningSheetPresented = false
    /// True while a Gemini Live session is active — suppresses PlaybackView auto-launch.
    @Published var isLiveSessionActive = false

    // MARK: - Data

    @Published var userProfile: UserProfile {
        didSet { PersistenceService.save(userProfile) }
    }
    @Published var selectedFamilyMember: FamilyMember?

    // MARK: - Services (shared singletons)

    let notificationService = NotificationService.shared

    /// Pre-loaded LLM service for faster session start. Loaded in background
    /// when voice mode is local and model is downloaded.
    private(set) var preloadedLLM: LocalLLMService?
    private var preloadTask: Task<Void, Never>?

    // MARK: - Init

    #if DEBUG
    /// Bump this number any time the sample data content changes.
    /// Every device that has an older stamp will reload fresh sample data on next launch.
    private static let sampleDataVersion = 3
    private static let sampleDataVersionKey = "loadedSampleDataVersion"
    #endif

    init() {
        #if DEBUG
        let loadedVersion = UserDefaults.standard.integer(forKey: Self.sampleDataVersionKey)
        if loadedVersion < Self.sampleDataVersion {
            // Sample data is newer than what's on device — reload it.
            PersistenceService.deleteAll()
            userProfile = .sampleData
            UserDefaults.standard.set(Self.sampleDataVersion, forKey: Self.sampleDataVersionKey)
        } else {
            userProfile = PersistenceService.load() ?? .sampleData
        }
        #else
        userProfile = PersistenceService.load() ?? .default
        #endif
    }

    // MARK: - Computed

    var userName: String { userProfile.name }
    var familyMembers: [FamilyMember] { userProfile.familyMembers }
    var memories: [Memory] { userProfile.memories }

    /// Returns `.local` when a local model is downloaded (always prefer on-device).
    /// Falls back to `.cloud` (Gemini) only when no local model is available.
    var voiceMode: VoiceSessionBridge.Mode {
        if ModelDownloadService.shared.isModelReady {
            return .local
        }
        return .cloud
    }

    // MARK: - LLM Pre-warming

    /// Pre-loads the LLM in background so tapping the mic is instant.
    func preloadLLMIfNeeded() {
        guard preloadedLLM == nil,
              ModelDownloadService.shared.isModelReady else { return }

        preloadTask?.cancel()
        preloadTask = Task {
            let config = ModelDownloadService.shared.selectedModel
            let modelPath = ModelDownloadService.shared.modelFileURL(for: config).path
            let llm = LocalLLMService(modelPath: modelPath, modelFamily: config.family)

            do {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    DispatchQueue.global(qos: .userInitiated).async {
                        do {
                            try llm.loadModel()
                            continuation.resume()
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
                guard !Task.isCancelled else {
                    llm.unloadModel()
                    return
                }
                self.preloadedLLM = llm
                #if DEBUG
                dprint("[AppVM] ✅ LLM pre-warmed and ready")
                #endif
            } catch {
                #if DEBUG
                dprint("[AppVM] ⚠️ LLM pre-warm failed: \(error.localizedDescription)")
                #endif
            }
        }
    }

    /// Releases the pre-loaded LLM (e.g. when switching to cloud mode).
    func releasePreloadedLLM() {
        preloadTask?.cancel()
        preloadTask = nil
        preloadedLLM?.unloadModel()
        preloadedLLM = nil
    }

    /// Takes ownership of the pre-loaded LLM. Returns nil if not available.
    func takePreloadedLLM() -> LocalLLMService? {
        let llm = preloadedLLM
        preloadedLLM = nil
        return llm
    }

    /// Reclaims a still-loaded LLM after a session ends, so it can be reused
    /// for the next session without reloading from disk.
    func reclaimLLM(_ llm: LocalLLMService) {
        guard llm.isLoaded else { return }
        preloadedLLM = llm
        #if DEBUG
        dprint("[AppVM] ♻️ Reclaimed loaded LLM for reuse")
        #endif
    }

    // MARK: - Onboarding

    func completeOnboarding() {
        userProfile.isOnboardingComplete = true
    }

    /// Loads the built-in Finnish family demo profile.
    /// Replaces all current data — useful for demos and testing.
    func loadSampleData() {
        PersistenceService.deleteAll()
        notificationService.cancelAll()
        selectedFamilyMember = nil
        selectedTab = .home
        userProfile = .sampleData   // isOnboardingComplete = true → goes straight to ContentView
    }

    /// Wipes all saved data and restarts the onboarding flow.
    /// Use this when setting up the app for a new person, or for testing.
    func resetToNewUser() {
        PersistenceService.deleteAll()
        notificationService.cancelAll()
        selectedFamilyMember = nil
        selectedTab = .home
        userProfile = .default   // didSet saves the empty profile; isOnboardingComplete = false → onboarding shows
    }

    // MARK: - Listening / Conversation

    func startListening() {
        listeningSheetPresented = true
    }

    func doneSpeaking() {
        listeningSheetPresented = false
    }

    func selectFamilyMember(_ member: FamilyMember) {
        selectedFamilyMember = member
    }

    // MARK: - Notifications

    /// Call after the user toggles notifications on/off in Settings.
    func rescheduleNotifications() {
        Task {
            if userProfile.notificationsEnabled {
                let granted = await notificationService.requestAuthorization()
                if granted {
                    await notificationService.reschedule(profile: userProfile)
                } else {
                    // System denied — revert toggle, user can allow in iOS Settings
                    userProfile.notificationsEnabled = false
                }
            } else {
                notificationService.cancelAll()
            }
        }
    }
}

// MARK: - Tab Definition

enum AppTab: String, CaseIterable {
    case home      = "Home"
    case memories  = "Memories"
    case family    = "Family"
    case music     = "Music"
    case settings  = "Settings"

    var icon: String {
        switch self {
        case .home:      return "house.fill"
        case .memories:  return "photo.on.rectangle.angled"
        case .family:    return "person.3.fill"
        case .music:     return "music.note.list"
        case .settings:  return "gearshape.fill"
        }
    }
}
