import Foundation

struct UserProfile: Codable {
    var name: String
    var familyMembers: [FamilyMember]
    var memories: [Memory]
    var preferredAIModel: AIModel
    var isVoiceCloningEnabled: Bool
    var notificationsEnabled: Bool

    static let `default` = UserProfile(
        name: "Harri",
        familyMembers: FamilyMember.mockData,
        memories: Memory.mockData,
        preferredAIModel: .geminiFlash,
        isVoiceCloningEnabled: true,
        notificationsEnabled: true
    )
}

enum AIModel: String, Codable, CaseIterable {
    case geminiPro = "Gemini Pro"
    case geminiFlash = "Gemini Flash"
}
