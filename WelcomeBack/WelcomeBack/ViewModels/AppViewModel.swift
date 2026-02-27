import Foundation
import SwiftUI

@MainActor
final class AppViewModel: ObservableObject {

    // MARK: - Navigation

    @Published var selectedTab: AppTab = .home
    @Published var listeningSheetPresented = false
    @Published var playbackSheetPresented = false

    // MARK: - Data

    @Published var userProfile: UserProfile = .default
    @Published var selectedFamilyMember: FamilyMember?
    @Published var selectedMemory: Memory?

    // MARK: - Computed

    var userName: String { userProfile.name }
    var familyMembers: [FamilyMember] { userProfile.familyMembers }
    var memories: [Memory] { userProfile.memories }

    // MARK: - Navigation Helpers

    func startListening() {
        listeningSheetPresented = true
    }

    func doneSpeaking() {
        listeningSheetPresented = false
        // Pick a random family member to respond (prototype behaviour)
        selectedFamilyMember = userProfile.familyMembers.randomElement()
        playbackSheetPresented = true
    }

    func selectFamilyMember(_ member: FamilyMember) {
        selectedFamilyMember = member
        playbackSheetPresented = true
    }

    func selectMemory(_ memory: Memory) {
        selectedMemory = memory
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
