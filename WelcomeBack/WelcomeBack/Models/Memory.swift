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

// MARK: - Mock Data
extension Memory {
    static let mockData: [Memory] = [
        Memory(
            id: "1",
            title: "Our Family",
            date: "Summer 2023",
            imageURL: "memory_lake_reunion",
            category: .family,
            description: "A wonderful day together with the whole family."
        ),
        Memory(
            id: "2",
            title: "Our Dog Pätkis",
            date: "",
            imageURL: "memory_sarah",
            category: .family,
            description: "Pätkis, our beloved family dog."
        ),
        Memory(
            id: "3",
            title: "Me and LUMI",
            date: "",
            imageURL: "memory_birthday_1960",
            category: .family,
            description: "A special moment with LUMI."
        ),
        Memory(
            id: "4",
            title: "Skiing at Karttimo",
            date: "",
            imageURL: "memory_lake_1972",
            category: .places,
            description: "Our cabin at Karttimo — winter days on the slopes."
        )
    ]
}
