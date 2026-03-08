import XCTest
@testable import WelcomeBack

final class UserProfileTests: XCTestCase {

    // MARK: - Default Profile

    func test_defaultProfile_hasExpectedName() {
        XCTAssertEqual(UserProfile.default.name, "Harri")
    }

    func test_defaultProfile_hasExpectedAIModel() {
        XCTAssertEqual(UserProfile.default.preferredAIModel, .geminiFlash)
    }

    func test_defaultProfile_voiceCloningEnabledByDefault() {
        XCTAssertTrue(UserProfile.default.isVoiceCloningEnabled)
    }

    func test_defaultProfile_notificationsEnabledByDefault() {
        XCTAssertTrue(UserProfile.default.notificationsEnabled)
    }

    func test_defaultProfile_containsMockFamilyMembers() {
        XCTAssertEqual(UserProfile.default.familyMembers.count, FamilyMember.mockData.count)
    }

    func test_defaultProfile_containsMockMemories() {
        XCTAssertEqual(UserProfile.default.memories.count, Memory.mockData.count)
    }

    // MARK: - Mutability

    func test_profile_canUpdateName() {
        var profile = UserProfile.default
        profile.name = "John"
        XCTAssertEqual(profile.name, "John")
    }

    func test_profile_canToggleVoiceCloning() {
        var profile = UserProfile.default
        profile.isVoiceCloningEnabled = false
        XCTAssertFalse(profile.isVoiceCloningEnabled)
    }

    func test_profile_canSwitchAIModel() {
        var profile = UserProfile.default
        profile.preferredAIModel = .geminiPro
        XCTAssertEqual(profile.preferredAIModel, .geminiPro)
    }

    func test_profile_canAddFamilyMember() {
        var profile = UserProfile.default
        let newMember = FamilyMember(
            id: "99", name: "Tom", relationship: "Brother",
            imageURL: "family_tom", isVoiceCloned: false
        )
        profile.familyMembers.append(newMember)
        XCTAssertEqual(profile.familyMembers.count, FamilyMember.mockData.count + 1)
        XCTAssertEqual(profile.familyMembers.last?.name, "Tom")
    }

    func test_profile_canAddMemory() {
        var profile = UserProfile.default
        let newMemory = Memory(
            id: "99", title: "New Memory", date: "2024",
            imageURL: "new_img", category: .other, description: "A new one."
        )
        profile.memories.append(newMemory)
        XCTAssertEqual(profile.memories.count, Memory.mockData.count + 1)
    }

    // MARK: - AIModel

    func test_aiModel_allCasesPresent() {
        XCTAssertEqual(AIModel.allCases.count, 2)
        XCTAssertTrue(AIModel.allCases.contains(.geminiPro))
        XCTAssertTrue(AIModel.allCases.contains(.geminiFlash))
    }

    func test_aiModel_rawValues() {
        XCTAssertEqual(AIModel.geminiPro.rawValue, "Gemini Pro")
        XCTAssertEqual(AIModel.geminiFlash.rawValue, "Gemini Flash")
    }

    // MARK: - Codable

    func test_userProfile_encodesAndDecodes() throws {
        let original = UserProfile.default
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(UserProfile.self, from: data)

        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.preferredAIModel, original.preferredAIModel)
        XCTAssertEqual(decoded.familyMembers.count, original.familyMembers.count)
        XCTAssertEqual(decoded.memories.count, original.memories.count)
        XCTAssertEqual(decoded.isVoiceCloningEnabled, original.isVoiceCloningEnabled)
    }
}
