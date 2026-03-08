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
    var preferredVoiceMode: VoiceMode
    var isVoiceCloningEnabled: Bool

    var notificationsEnabled: Bool
    var notificationTimes: [NotificationTime]
    var notificationTopics: String      // free-form text

    var isOnboardingComplete: Bool

    // MARK: - Migration-safe Codable

    enum CodingKeys: String, CodingKey {
        case name, profileImageURL, address, biography, currentLocation
        case familyMembers, memories
        case preferredAIModel, preferredVoiceMode, isVoiceCloningEnabled
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
        preferredVoiceMode: VoiceMode = .cloud,
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
        self.preferredVoiceMode = preferredVoiceMode
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
        preferredVoiceMode   = (try? c.decode(VoiceMode.self,        forKey: .preferredVoiceMode))   ?? .cloud
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
        try c.encode(preferredVoiceMode,   forKey: .preferredVoiceMode)
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

    // MARK: - Sample / Demo data (Finnish family — Harri, Anna, Toivo, Helmi, Pätkis)

    static let sampleData = UserProfile(
        name: "Harri",
        profileImageURL: "user_harri",
        address: "Mechelininkatu 12, 00100 Helsinki",
        biography: "Retired civil engineer who spent 35 years designing bridges and roads across Finland. Born and raised in Tampere, I moved to Helsinki after meeting Anna. I love fishing on Lake Saimaa, tending our summer cottage garden, and listening to old tango records.",
        currentLocation: "Helsinki, Finland",
        familyMembers: [
            FamilyMember(
                id: "anna-juntunen",
                name: "Anna",
                relationship: "Wife",
                phone: "+358 40 123 4567",
                biography: "Anna and I met at a dance in Tampere in 1978. She was wearing a red dress and laughed at all my jokes. We married two years later at Porvoo Cathedral. She worked as a primary school teacher for 30 years and has the most patient, kind heart of anyone I know. She makes the best mustikkapiirakka in all of Finland.",
                memory1: "Our wedding day, June 14, 1980. The church bells rang out over Porvoo and Anna walked down the aisle in her mother's lace dress. We danced until midnight at the reception and drove to Tallinn for our honeymoon. I have never seen her more beautiful than on that day.",
                memory2: "Every summer Anna would pack the whole family into the old Volvo and drive to the cottage at Lake Saimaa. She would wake before dawn to pick wild blueberries and have piirakka ready by the time the children were awake. Those mornings smell like pine and fresh pastry to me.",
                imageURL: "family_susan",
                additionalPhotoURLs: [],
                isVoiceCloned: false
            ),
            FamilyMember(
                id: "toivo-juntunen",
                name: "Toivo",
                relationship: "Son",
                phone: "+358 44 987 6543",
                biography: "Our firstborn, Toivo, arrived in 1983. He has my stubbornness and Anna's warmth. He studied software engineering at Aalto University and now works at a tech company in Espoo. He calls every Sunday evening without fail. He has two children of his own — Mikael and Sofia — who call me Isoisä.",
                memory1: "The day Toivo was born a snowstorm shut down the whole city of Helsinki. I drove to the hospital through white-out conditions at three in the morning. When the nurse placed him in my arms he looked up at me with huge dark eyes and I cried for the first time since I was a boy.",
                memory2: "Toivo caught his first pike at the cottage when he was seven. He was so proud he insisted we photograph it before throwing it back. He named the fish Paavo and talked about Paavo for the rest of that entire summer.",
                imageURL: "family_michael",
                additionalPhotoURLs: [],
                isVoiceCloned: false
            ),
            FamilyMember(
                id: "helmi-juntunen",
                name: "Helmi",
                relationship: "Daughter",
                phone: "+358 50 555 7890",
                biography: "Helmi was born in 1986 and from the start she had a spirit bigger than the room. She studied architecture in Tampere and now runs her own studio designing sustainable wooden houses. She lives in Turku with her partner Eero and visits most weekends, always bringing good wine and too many opinions about interior design.",
                memory1: "Helmi performed in her school Christmas play when she was nine. She played the role of a star — literally wrapped in silver foil — and delivered every line with a confidence I have never seen before or since. The whole audience laughed and she bowed three times.",
                memory2: "When Helmi was sixteen she insisted on hiking the Karhunkierros trail with me. It rained every single day. She never once complained. On the last morning the sun came out just as we reached the Oulanka canyon and she grabbed my hand and said, 'Isä, this is the best thing we have ever done.'",
                imageURL: "family_emily",
                additionalPhotoURLs: [],
                isVoiceCloned: false
            ),
            FamilyMember(
                id: "patkis-juntunen",
                name: "Pätkis",
                relationship: "Our Dog",
                phone: "",
                biography: "Pätkis is a five-year-old golden retriever who came into our lives as a tiny, round puppy. He was named Pätkis because of the little patch of white fur on his chest that looks like a dairy chocolate. He sleeps on my feet every evening and has never once judged me for anything.",
                memory1: "The day we brought Pätkis home he was so small he fit in the pocket of my winter coat. He trembled all the way from the breeder in Järvenpää. The moment Helmi sat down on the sofa he climbed onto her lap, sighed deeply, and fell asleep — and that was that, he was ours.",
                memory2: "Pätkis and I have a morning ritual: every day at seven I put on my old walking boots and he spins in circles by the door making a sound somewhere between a bark and a yodel. We walk along the sea at Merikasarmi and he chases every seagull he sees. He has never caught one. He will never stop trying.",
                imageURL: "family_jane",
                additionalPhotoURLs: [],
                isVoiceCloned: false
            )
        ],
        memories: [
            Memory(
                id: "memory-wedding",
                title: "Our Wedding Day",
                date: "June 14, 1980",
                imageURL: "memory_birthday_1960",
                category: .family,
                description: "Anna and I were married at Porvoo Cathedral on a warm June afternoon. The old stone church was full of sunflowers. We wrote our own vows and Anna cried through both of them. Afterwards we danced in the courtyard of a riverside restaurant while a small band played Finnish tangos. It was the happiest day of my life."
            ),
            Memory(
                id: "memory-cottage",
                title: "Summer at the Saimaa Cottage",
                date: "July 1991",
                imageURL: "memory_lake_1972",
                category: .places,
                description: "Three weeks at our cottage on Lake Saimaa. Toivo was eight and Helmi was five. We swam, fished, picked blueberries, and sat on the dock watching the sunset turn the water pink and gold. I built a small raft for the children and we named it the SS Salminen. It sank on the third day and we still talk about it."
            ),
            Memory(
                id: "memory-lapland",
                title: "Christmas in Lapland",
                date: "December 25, 1995",
                imageURL: "",
                category: .events,
                description: "We drove the whole family up to a log cabin in Saariselkä for Christmas. There was so much snow the car was buried to its door handles. The Northern Lights came out on Christmas Eve — green and violet curtains across the whole sky. Toivo and Helmi lay on their backs in the snow staring up in silence. I still see that exact image when I close my eyes."
            ),
            Memory(
                id: "memory-patkis-arrival",
                title: "The Day Pätkis Arrived",
                date: "March 3, 2019",
                imageURL: "memory_sarah",
                category: .family,
                description: "Helmi surprised Anna and me with a golden retriever puppy for our anniversary. He arrived in a cardboard box with air holes and a red bow, eight weeks old with enormous paws. We spent the whole afternoon on the floor with him and completely forgot the anniversary dinner we had planned."
            ),
            Memory(
                id: "memory-retirement",
                title: "Retirement Party",
                date: "May 30, 2018",
                imageURL: "memory_lake_reunion",
                category: .events,
                description: "After 35 years at the engineering firm, my colleagues organised a surprise party. They had built a model of the Koskela Bridge — one of the projects I was proudest of — out of matchsticks and cardboard. I gave a speech and managed not to cry until I was safely in the car."
            ),
            Memory(
                id: "memory-tampere",
                title: "Growing Up in Tampere",
                date: "Summer 1968",
                imageURL: "",
                category: .places,
                description: "I grew up on Hämeenkatu in Tampere, the son of a factory foreman and a seamstress. Summer meant the city pool, riding bikes along the river Tammerkoski, and eating ice cream outside the market hall. I remember the smell of the textile factories — warm wool and machine oil — that drifted across the neighbourhood on still evenings."
            )
        ],
        preferredAIModel: .geminiFlash,
        isVoiceCloningEnabled: false,
        notificationsEnabled: false,
        notificationTimes: [.morning],
        notificationTopics: "Family memories, cottage summers, life in Finland",
        isOnboardingComplete: true
    )
}

// MARK: - Supporting types

enum VoiceMode: String, Codable, CaseIterable {
    case cloud = "Cloud (Gemini)"
    case local = "Local (On-Device)"
}

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
