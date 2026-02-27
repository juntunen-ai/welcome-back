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
            biography: "",
            memory1: "",
            memory2: "",
            imageURL: "family_jane",
            isVoiceCloned: true
        ),
        FamilyMember(
            id: "2",
            name: "Toivo",
            relationship: "Son",
            phone: "",
            biography: "",
            memory1: "",
            memory2: "",
            imageURL: "family_michael",
            isVoiceCloned: false
        ),
        FamilyMember(
            id: "3",
            name: "Anna",
            relationship: "Wife",
            phone: "",
            biography: "",
            memory1: "",
            memory2: "",
            imageURL: "family_susan",
            isVoiceCloned: true
        ),
        FamilyMember(
            id: "4",
            name: "My Parents & Children",
            relationship: "Family",
            phone: "",
            biography: "",
            memory1: "",
            memory2: "",
            imageURL: "family_emily",
            isVoiceCloned: true
        )
    ]
}
