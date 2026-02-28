import Foundation

struct FamilyMember: Identifiable, Codable {
    let id: String
    var name: String
    var relationship: String
    var phone: String
    var biography: String
    var memory1: String
    var memory2: String
    var imageURL: String
    var isVoiceCloned: Bool
    var voiceProfileID: String?
}

// MARK: - Mock Data
extension FamilyMember {
    static let mockData: [FamilyMember] = [
        FamilyMember(
            id: "1",
            name: "Helmi",
            relationship: "Daughter",
            phone: "",
            biography: "Helmi is our wonderful daughter, full of warmth and laughter. She always knows how to brighten the room and looks after everyone around her.",
            memory1: "We used to bake cinnamon rolls together every Sunday morning. The whole house smelled amazing and we'd sit at the kitchen table talking for hours.",
            memory2: "Helmi surprised me with a handmade birthday card when she was seven. She had drawn our whole family and written 'Best Dad Ever' in big wobbly letters. I still have it.",
            imageURL: "family_jane",
            isVoiceCloned: true
        ),
        FamilyMember(
            id: "2",
            name: "Toivo",
            relationship: "Son",
            phone: "",
            biography: "Toivo is our curious and adventurous son. He has a big heart and a great sense of humour. He loves the outdoors and always has a new project on the go.",
            memory1: "When Toivo was ten we went fishing together at the lake near the summer cottage. He caught his first pike and couldn't stop talking about it for weeks.",
            memory2: "Every Christmas Eve Toivo would wake up before everyone else and tiptoe to the living room to check under the tree. We would pretend to be asleep and watch him with a smile.",
            imageURL: "family_michael",
            isVoiceCloned: false
        ),
        FamilyMember(
            id: "3",
            name: "Anna",
            relationship: "Wife",
            phone: "",
            biography: "Anna is my beloved wife and the heart of our family. She is kind, patient, and endlessly supportive. Life with her has been the greatest gift.",
            memory1: "Our first date was a walk along the river on a crisp autumn evening. We talked so long we missed the last tram and laughed all the way home.",
            memory2: "Every summer we spend a week at the cottage together. Anna makes coffee on the old wood stove and we sit on the dock watching the sunrise. Those mornings are my favourite.",
            imageURL: "family_susan",
            isVoiceCloned: true
        ),
        FamilyMember(
            id: "4",
            name: "My Parents & Children",
            relationship: "Family",
            phone: "",
            biography: "My parents gave me roots and my children gave me wings. Together they are the foundation of everything I hold dear.",
            memory1: "Midsummer celebrations at my parents' garden — the bonfire, the singing, and all of us gathered around the table late into the bright summer night.",
            memory2: "A family road trip where the car broke down and we ended up spending an unplanned night in a small town. It became one of our favourite stories to tell.",
            imageURL: "family_emily",
            isVoiceCloned: true
        )
    ]
}
