import Foundation

struct FamilyMember: Identifiable, Codable {
    let id: String
    var name: String
    var relationship: String
    var phone: String
    var biography: String
    var memory1: String
    var memory2: String
    var imageURL: String              // primary profile photo
    var additionalPhotoURLs: [String] // gallery photos shown on profile page
    var isVoiceCloned: Bool
    var voiceProfileID: String?

    // MARK: - Init (defaults on new fields so existing call sites compile unchanged)

    init(id: String, name: String, relationship: String,
         phone: String = "", biography: String = "",
         memory1: String = "", memory2: String = "",
         imageURL: String, additionalPhotoURLs: [String] = [],
         isVoiceCloned: Bool, voiceProfileID: String? = nil) {
        self.id = id
        self.name = name
        self.relationship = relationship
        self.phone = phone
        self.biography = biography
        self.memory1 = memory1
        self.memory2 = memory2
        self.imageURL = imageURL
        self.additionalPhotoURLs = additionalPhotoURLs
        self.isVoiceCloned = isVoiceCloned
        self.voiceProfileID = voiceProfileID
    }

    // MARK: - Codable (migration-safe: missing keys fall back to empty defaults)

    enum CodingKeys: String, CodingKey {
        case id, name, relationship, phone, biography
        case memory1, memory2, imageURL, additionalPhotoURLs
        case isVoiceCloned, voiceProfileID
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                  = try  c.decode(String.self,   forKey: .id)
        name                = try  c.decode(String.self,   forKey: .name)
        relationship        = try  c.decode(String.self,   forKey: .relationship)
        phone               = (try? c.decode(String.self,  forKey: .phone))               ?? ""
        biography           = (try? c.decode(String.self,  forKey: .biography))           ?? ""
        memory1             = (try? c.decode(String.self,  forKey: .memory1))             ?? ""
        memory2             = (try? c.decode(String.self,  forKey: .memory2))             ?? ""
        imageURL            = (try? c.decode(String.self,  forKey: .imageURL))            ?? ""
        additionalPhotoURLs = (try? c.decode([String].self, forKey: .additionalPhotoURLs)) ?? []
        isVoiceCloned       = (try? c.decode(Bool.self,    forKey: .isVoiceCloned))       ?? false
        voiceProfileID      = try? c.decode(String.self,   forKey: .voiceProfileID)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,                   forKey: .id)
        try c.encode(name,                 forKey: .name)
        try c.encode(relationship,         forKey: .relationship)
        try c.encode(phone,                forKey: .phone)
        try c.encode(biography,            forKey: .biography)
        try c.encode(memory1,              forKey: .memory1)
        try c.encode(memory2,              forKey: .memory2)
        try c.encode(imageURL,             forKey: .imageURL)
        try c.encode(additionalPhotoURLs,  forKey: .additionalPhotoURLs)
        try c.encode(isVoiceCloned,        forKey: .isVoiceCloned)
        try c.encodeIfPresent(voiceProfileID, forKey: .voiceProfileID)
    }
}
