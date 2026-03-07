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

    // MARK: - Init

    /// Bump this number any time the sample data content changes.
    /// Every device that has an older stamp will reload fresh sample data on next launch.
    private static let sampleDataVersion = 3
    private static let sampleDataVersionKey = "loadedSampleDataVersion"

    init() {
        let loadedVersion = UserDefaults.standard.integer(forKey: Self.sampleDataVersionKey)
        if loadedVersion < Self.sampleDataVersion {
            // Sample data is newer than what's on device — reload it.
            PersistenceService.deleteAll()
            userProfile = .sampleData
            UserDefaults.standard.set(Self.sampleDataVersion, forKey: Self.sampleDataVersionKey)
        } else {
            userProfile = PersistenceService.load() ?? .sampleData
        }
    }

    // MARK: - Computed

    var userName: String { userProfile.name }
    var familyMembers: [FamilyMember] { userProfile.familyMembers }
    var memories: [Memory] { userProfile.memories }

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
        selectedFamilyMember = userProfile.familyMembers.randomElement()
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
