import Foundation

struct UserProfile: Codable {
    var name: String
    var profileImageURL: String      // "photo:user_profile.jpg" or "" if not set
    var address: String
    var biography: String
    var currentLocation: String

    var familyMembers: [FamilyMember]
    var memories: [Memory]

    var preferredAIModel: AIModel
    var isVoiceCloningEnabled: Bool

    var notificationsEnabled: Bool
    var notificationTimes: [NotificationTime]
    var notificationTopics: String      // free-form text

    var isOnboardingComplete: Bool

    // MARK: - Migration-safe Codable

    enum CodingKeys: String, CodingKey {
        case name, profileImageURL, address, biography, currentLocation
        case familyMembers, memories
        case preferredAIModel, isVoiceCloningEnabled
        case notificationsEnabled, notificationTimes, notificationTopics
        case isOnboardingComplete
        // Note: socialSecurityNumber is intentionally omitted — field removed for privacy
    }

    init(
        name: String,
        profileImageURL: String = "",
        address: String = "",
        biography: String = "",
        currentLocation: String = "",
        familyMembers: [FamilyMember] = [],
        memories: [Memory] = [],
        preferredAIModel: AIModel = .geminiFlash,
        isVoiceCloningEnabled: Bool = false,
        notificationsEnabled: Bool = false,
        notificationTimes: [NotificationTime] = [.morning],
        notificationTopics: String = "",
        isOnboardingComplete: Bool = false
    ) {
        self.name = name
        self.profileImageURL = profileImageURL
        self.address = address
        self.biography = biography
        self.currentLocation = currentLocation
        self.familyMembers = familyMembers
        self.memories = memories
        self.preferredAIModel = preferredAIModel
        self.isVoiceCloningEnabled = isVoiceCloningEnabled
        self.notificationsEnabled = notificationsEnabled
        self.notificationTimes = notificationTimes
        self.notificationTopics = notificationTopics
        self.isOnboardingComplete = isOnboardingComplete
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name                 = (try? c.decode(String.self,            forKey: .name))                 ?? ""
        profileImageURL      = (try? c.decode(String.self,            forKey: .profileImageURL))      ?? ""
        address              = (try? c.decode(String.self,            forKey: .address))              ?? ""
        biography            = (try? c.decode(String.self,            forKey: .biography))            ?? ""
        currentLocation      = (try? c.decode(String.self,            forKey: .currentLocation))      ?? ""
        familyMembers        = (try? c.decode([FamilyMember].self,    forKey: .familyMembers))        ?? []
        memories             = (try? c.decode([Memory].self,          forKey: .memories))             ?? []
        preferredAIModel     = (try? c.decode(AIModel.self,           forKey: .preferredAIModel))     ?? .geminiFlash
        isVoiceCloningEnabled = (try? c.decode(Bool.self,             forKey: .isVoiceCloningEnabled)) ?? false
        notificationsEnabled = (try? c.decode(Bool.self,              forKey: .notificationsEnabled)) ?? false
        notificationTimes    = (try? c.decode([NotificationTime].self, forKey: .notificationTimes))   ?? [.morning]
        notificationTopics   = (try? c.decode(String.self,            forKey: .notificationTopics))   ?? ""
        isOnboardingComplete = (try? c.decode(Bool.self,              forKey: .isOnboardingComplete)) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name,                  forKey: .name)
        try c.encode(profileImageURL,       forKey: .profileImageURL)
        try c.encode(address,               forKey: .address)
        try c.encode(biography,             forKey: .biography)
        try c.encode(currentLocation,       forKey: .currentLocation)
        try c.encode(familyMembers,         forKey: .familyMembers)
        try c.encode(memories,              forKey: .memories)
        try c.encode(preferredAIModel,      forKey: .preferredAIModel)
        try c.encode(isVoiceCloningEnabled, forKey: .isVoiceCloningEnabled)
        try c.encode(notificationsEnabled,  forKey: .notificationsEnabled)
        try c.encode(notificationTimes,     forKey: .notificationTimes)
        try c.encode(notificationTopics,    forKey: .notificationTopics)
        try c.encode(isOnboardingComplete,  forKey: .isOnboardingComplete)
    }

    // MARK: - Default (used for new installs — onboarding will populate the real data)

    static let `default` = UserProfile(
        name: "",
        familyMembers: [],
        memories: [],
        isOnboardingComplete: false
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
