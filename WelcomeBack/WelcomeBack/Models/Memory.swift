import Foundation

struct Memory: Identifiable, Codable, Hashable {
    let id: String
    var title: String
    var date: String
    var imageURL: String
    var category: MemoryCategory
    var description: String
}

enum MemoryCategory: String, Codable, CaseIterable, Hashable {
    case family = "Family"
    case events = "Events"
    case places = "Places"
    case other = "Other"
}
