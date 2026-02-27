import XCTest
@testable import WelcomeBack

final class MemoryTests: XCTestCase {

    // MARK: - Initialisation

    func test_memory_init_storesAllProperties() {
        let memory = Memory(
            id: "42",
            title: "Summer Holiday",
            date: "July 1978",
            imageURL: "holiday_1978",
            category: .places,
            description: "A warm week by the sea."
        )

        XCTAssertEqual(memory.id, "42")
        XCTAssertEqual(memory.title, "Summer Holiday")
        XCTAssertEqual(memory.date, "July 1978")
        XCTAssertEqual(memory.imageURL, "holiday_1978")
        XCTAssertEqual(memory.category, .places)
        XCTAssertEqual(memory.description, "A warm week by the sea.")
    }

    // MARK: - MemoryCategory

    func test_memoryCategory_allCasesPresent() {
        let cases = MemoryCategory.allCases
        XCTAssertTrue(cases.contains(.family))
        XCTAssertTrue(cases.contains(.events))
        XCTAssertTrue(cases.contains(.places))
        XCTAssertTrue(cases.contains(.other))
        XCTAssertEqual(cases.count, 4)
    }

    func test_memoryCategory_rawValues() {
        XCTAssertEqual(MemoryCategory.family.rawValue, "Family")
        XCTAssertEqual(MemoryCategory.events.rawValue, "Events")
        XCTAssertEqual(MemoryCategory.places.rawValue, "Places")
        XCTAssertEqual(MemoryCategory.other.rawValue, "Other")
    }

    func test_memoryCategory_decodesFromRawValue() {
        XCTAssertEqual(MemoryCategory(rawValue: "Family"), .family)
        XCTAssertEqual(MemoryCategory(rawValue: "Events"), .events)
        XCTAssertNil(MemoryCategory(rawValue: "Unknown"))
    }

    // MARK: - Codable

    func test_memory_encodesAndDecodes() throws {
        let original = Memory(
            id: "1",
            title: "Test Memory",
            date: "June 2000",
            imageURL: "test_img",
            category: .events,
            description: "A test."
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Memory.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.category, original.category)
    }

    // MARK: - Mock Data

    func test_mockData_hasExpectedCount() {
        XCTAssertEqual(Memory.mockData.count, 4)
    }

    func test_mockData_allIdsAreUnique() {
        let ids = Memory.mockData.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func test_mockData_allTitlesNonEmpty() {
        for memory in Memory.mockData {
            XCTAssertFalse(memory.title.isEmpty, "Memory \(memory.id) has an empty title")
        }
    }

    func test_mockData_containsExpectedCategories() {
        let categories = Set(Memory.mockData.map(\.category))
        XCTAssertTrue(categories.contains(.family))
        XCTAssertTrue(categories.contains(.events))
        XCTAssertTrue(categories.contains(.places))
    }
}
