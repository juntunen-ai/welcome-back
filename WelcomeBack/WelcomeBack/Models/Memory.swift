import Foundation

struct Memory: Identifiable, Codable {
    let id: String
    var title: String
    var date: String
    var imageURL: String
    var category: MemoryCategory
    var description: String
}

enum MemoryCategory: String, Codable, CaseIterable {
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
            date: "Autumn 2022",
            imageURL: "memory_sarah",
            category: .family,
            description: "Pätkis, our beloved family dog."
        ),
        Memory(
            id: "3",
            title: "June 1960 Birthday",
            date: "June 1960",
            imageURL: "memory_birthday_1960",
            category: .events,
            description: "A celebration with a big blue cake."
        ),
        Memory(
            id: "4",
            title: "The Lake",
            date: "August 1972",
            imageURL: "memory_lake_1972",
            category: .places,
            description: "Quiet moments by the water."
        )
    ]
}
