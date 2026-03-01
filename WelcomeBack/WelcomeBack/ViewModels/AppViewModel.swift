import Foundation
import SwiftUI

@MainActor
final class AppViewModel: ObservableObject {

    // MARK: - Navigation

    @Published var selectedTab: AppTab = .home
    @Published var listeningSheetPresented = false
    /// True while a Gemini Live session is active — suppresses PlaybackView auto-launch.
    @Published var isLiveSessionActive = false
    @Published var showPaywall = false

    // MARK: - Data

    @Published var userProfile: UserProfile {
        didSet { PersistenceService.save(userProfile) }
    }
    @Published var selectedFamilyMember: FamilyMember?

    // MARK: - Services (shared singletons)

    let subscriptionService = SubscriptionService.shared
    let notificationService = NotificationService.shared

    // MARK: - Init

    init() {
        userProfile = PersistenceService.load() ?? .default
    }

    // MARK: - Computed

    var userName: String { userProfile.name }
    var familyMembers: [FamilyMember] { userProfile.familyMembers }
    var memories: [Memory] { userProfile.memories }
    var isPremium: Bool { subscriptionService.isPremium }

    // MARK: - Onboarding

    func completeOnboarding() {
        userProfile.isOnboardingComplete = true
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
        // Gate free-tier users once the monthly limit is reached
        if subscriptionService.hasReachedFreeLimit {
            showPaywall = true
            return
        }
        subscriptionService.incrementConversationCount()
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
            // Gate: notifications require Premium
            if userProfile.notificationsEnabled && !isPremium {
                showPaywall = true
                userProfile.notificationsEnabled = false
                return
            }

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
