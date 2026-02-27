import XCTest
@testable import WelcomeBack

@MainActor
final class AppViewModelTests: XCTestCase {

    var sut: AppViewModel!

    override func setUp() {
        super.setUp()
        sut = AppViewModel()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func test_initialState_selectedTabIsHome() {
        XCTAssertEqual(sut.selectedTab, .home)
    }

    func test_initialState_listeningSheetNotPresented() {
        XCTAssertFalse(sut.listeningSheetPresented)
    }

    func test_initialState_playbackSheetNotPresented() {
        XCTAssertFalse(sut.playbackSheetPresented)
    }

    func test_initialState_noSelectedFamilyMember() {
        XCTAssertNil(sut.selectedFamilyMember)
    }

    func test_initialState_userNameFromDefaultProfile() {
        XCTAssertEqual(sut.userName, UserProfile.default.name)
    }

    // MARK: - startListening

    func test_startListening_opensListeningSheet() {
        sut.startListening()
        XCTAssertTrue(sut.listeningSheetPresented)
    }

    func test_startListening_doesNotOpenPlaybackSheet() {
        sut.startListening()
        XCTAssertFalse(sut.playbackSheetPresented)
    }

    // MARK: - doneSpeaking

    func test_doneSpeaking_closesListeningSheet() {
        sut.startListening()
        sut.doneSpeaking()
        XCTAssertFalse(sut.listeningSheetPresented)
    }

    func test_doneSpeaking_opensPlaybackSheet() {
        sut.doneSpeaking()
        XCTAssertTrue(sut.playbackSheetPresented)
    }

    func test_doneSpeaking_selectsAFamilyMember() {
        sut.doneSpeaking()
        XCTAssertNotNil(sut.selectedFamilyMember)
    }

    func test_doneSpeaking_selectsMemberFromExistingFamily() {
        sut.doneSpeaking()
        let selectedID = sut.selectedFamilyMember?.id
        let allIDs = sut.familyMembers.map(\.id)
        XCTAssertTrue(allIDs.contains(selectedID ?? ""))
    }

    func test_doneSpeaking_withNoFamilyMembers_selectedMemberIsNil() {
        sut.userProfile.familyMembers = []
        sut.doneSpeaking()
        XCTAssertNil(sut.selectedFamilyMember)
    }

    // MARK: - selectFamilyMember

    func test_selectFamilyMember_setsSelectedMember() {
        let member = FamilyMember.mockData[0]
        sut.selectFamilyMember(member)
        XCTAssertEqual(sut.selectedFamilyMember?.id, member.id)
    }

    func test_selectFamilyMember_opensPlaybackSheet() {
        sut.selectFamilyMember(FamilyMember.mockData[0])
        XCTAssertTrue(sut.playbackSheetPresented)
    }

    func test_selectFamilyMember_selectsExactMember() {
        let member = FamilyMember.mockData.first { $0.name == "My Parents & Children" }!
        sut.selectFamilyMember(member)
        XCTAssertEqual(sut.selectedFamilyMember?.name, "My Parents & Children")
    }

    // MARK: - selectMemory

    func test_selectMemory_opensPlaybackSheet() {
        sut.selectMemory(Memory.mockData[0])
        XCTAssertTrue(sut.playbackSheetPresented)
    }

    func test_selectMemory_selectsAFamilyMember() {
        sut.selectMemory(Memory.mockData[0])
        XCTAssertNotNil(sut.selectedFamilyMember)
    }

    // MARK: - Tab Navigation

    func test_selectedTab_canBeChanged() {
        sut.selectedTab = .family
        XCTAssertEqual(sut.selectedTab, .family)
    }

    func test_allTabs_haveNonEmptyIcons() {
        for tab in AppTab.allCases {
            XCTAssertFalse(tab.icon.isEmpty, "\(tab.rawValue) has an empty icon name")
        }
    }

    func test_allTabs_haveNonEmptyRawValues() {
        for tab in AppTab.allCases {
            XCTAssertFalse(tab.rawValue.isEmpty)
        }
    }

    // MARK: - Computed Properties

    func test_userName_reflectsUserProfile() {
        sut.userProfile.name = "TestUser"
        XCTAssertEqual(sut.userName, "TestUser")
    }

    func test_familyMembers_reflectsUserProfile() {
        XCTAssertEqual(sut.familyMembers.count, sut.userProfile.familyMembers.count)
    }

    func test_memories_reflectsUserProfile() {
        XCTAssertEqual(sut.memories.count, sut.userProfile.memories.count)
    }
}
