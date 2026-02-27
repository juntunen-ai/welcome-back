import Foundation

struct FamilyMember: Identifiable, Codable {
    let id: String
    var name: String
    var relationship: String
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
            imageURL: "family_jane",
            isVoiceCloned: true
        ),
        FamilyMember(
            id: "2",
            name: "Toivo",
            relationship: "Son",
            imageURL: "family_michael",
            isVoiceCloned: false
        ),
        FamilyMember(
            id: "3",
            name: "Anna",
            relationship: "Wife",
            imageURL: "family_susan",
            isVoiceCloned: true
        ),
        FamilyMember(
            id: "4",
            name: "My Parents & Children",
            relationship: "Family",
            imageURL: "family_emily",
            isVoiceCloned: true
        )
    ]
}
