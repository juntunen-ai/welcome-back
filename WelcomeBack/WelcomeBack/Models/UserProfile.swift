import Foundation

struct UserProfile: Codable {
    var name: String
    var address: String
    var socialSecurityNumber: String
    var biography: String
    var currentLocation: String

    var familyMembers: [FamilyMember]
    var memories: [Memory]

    var preferredAIModel: AIModel
    var isVoiceCloningEnabled: Bool

    var notificationsEnabled: Bool
    var notificationTimes: [NotificationTime]
    var notificationTopics: String      // free-form text

    static let `default` = UserProfile(
        name: "Harri",
        address: "",
        socialSecurityNumber: "",
        biography: "",
        currentLocation: "",
        familyMembers: FamilyMember.mockData,
        memories: Memory.mockData,
        preferredAIModel: .geminiFlash,
        isVoiceCloningEnabled: true,
        notificationsEnabled: true,
        notificationTimes: [.morning],
        notificationTopics: ""
    )
}

// MARK: - Supporting types

enum AIModel: String, Codable, CaseIterable {
    case geminiPro  = "Gemini Pro"
    case geminiFlash = "Gemini Flash"
}

enum NotificationTime: String, Codable, CaseIterable, Identifiable {
    case morning   = "Morning (9:00)"
    case noon      = "Noon (12:00)"
    case afternoon = "Afternoon (15:00)"
    case evening   = "Evening (18:00)"

    var id: String { rawValue }
}
