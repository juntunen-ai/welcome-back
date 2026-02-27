import XCTest
@testable import WelcomeBack

final class FamilyMemberTests: XCTestCase {

    // MARK: - Initialisation

    func test_familyMember_init_storesAllProperties() {
        let member = FamilyMember(
            id: "99",
            name: "Anna",
            relationship: "Sister",
            imageURL: "family_anna",
            isVoiceCloned: false,
            voiceProfileID: nil
        )

        XCTAssertEqual(member.id, "99")
        XCTAssertEqual(member.name, "Anna")
        XCTAssertEqual(member.relationship, "Sister")
        XCTAssertEqual(member.imageURL, "family_anna")
        XCTAssertFalse(member.isVoiceCloned)
        XCTAssertNil(member.voiceProfileID)
    }

    func test_familyMember_withVoiceProfile_storesID() {
        let member = FamilyMember(
            id: "1",
            name: "Helmi",
            relationship: "Daughter",
            imageURL: "family_jane",
            isVoiceCloned: true,
            voiceProfileID: "voice-abc-123"
        )

        XCTAssertTrue(member.isVoiceCloned)
        XCTAssertEqual(member.voiceProfileID, "voice-abc-123")
    }

    // MARK: - Codable

    func test_familyMember_encodesAndDecodes() throws {
        let original = FamilyMember(
            id: "2",
            name: "Toivo",
            relationship: "Son",
            imageURL: "family_michael",
            isVoiceCloned: false
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FamilyMember.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.relationship, original.relationship)
        XCTAssertEqual(decoded.isVoiceCloned, original.isVoiceCloned)
    }

    func test_familyMember_encodesAndDecodes_withVoiceProfileID() throws {
        let original = FamilyMember(
            id: "3",
            name: "Anna",
            relationship: "Wife",
            imageURL: "family_susan",
            isVoiceCloned: true,
            voiceProfileID: "vp-001"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FamilyMember.self, from: data)

        XCTAssertEqual(decoded.voiceProfileID, "vp-001")
    }

    // MARK: - Mock Data

    func test_mockData_hasExpectedCount() {
        XCTAssertEqual(FamilyMember.mockData.count, 4)
    }

    func test_mockData_allIdsAreUnique() {
        let ids = FamilyMember.mockData.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func test_mockData_allNamesNonEmpty() {
        for member in FamilyMember.mockData {
            XCTAssertFalse(member.name.isEmpty, "FamilyMember \(member.id) has an empty name")
        }
    }

    func test_mockData_expectedVoiceClonedCount() {
        let cloned = FamilyMember.mockData.filter(\.isVoiceCloned)
        // Helmi, Anna, Emily are voice cloned; Toivo is not
        XCTAssertEqual(cloned.count, 3)
    }

    func test_mockData_toivoIsNotVoiceCloned() {
        let toivo = FamilyMember.mockData.first { $0.name == "Toivo" }
        XCTAssertNotNil(toivo)
        XCTAssertFalse(toivo!.isVoiceCloned)
    }
}
