import Foundation

struct Place: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var description: String
    var imageURL: String          // "photo:..." or asset catalog name
    var latitude: Double
    var longitude: Double

    // MARK: - Init

    init(id: String = UUID().uuidString,
         name: String = "",
         description: String = "",
         imageURL: String = "",
         latitude: Double = 0,
         longitude: Double = 0) {
        self.id = id
        self.name = name
        self.description = description
        self.imageURL = imageURL
        self.latitude = latitude
        self.longitude = longitude
    }

    // MARK: - Migration-safe Codable

    enum CodingKeys: String, CodingKey {
        case id, name, description, imageURL
        case latitude, longitude
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = (try? c.decode(String.self, forKey: .id))          ?? UUID().uuidString
        name        = (try? c.decode(String.self, forKey: .name))        ?? ""
        description = (try? c.decode(String.self, forKey: .description)) ?? ""
        imageURL    = (try? c.decode(String.self, forKey: .imageURL))    ?? ""
        latitude    = (try? c.decode(Double.self, forKey: .latitude))    ?? 0
        longitude   = (try? c.decode(Double.self, forKey: .longitude))   ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,          forKey: .id)
        try c.encode(name,        forKey: .name)
        try c.encode(description, forKey: .description)
        try c.encode(imageURL,    forKey: .imageURL)
        try c.encode(latitude,    forKey: .latitude)
        try c.encode(longitude,   forKey: .longitude)
    }
}
