import XCTest
@testable import WelcomeBack

@MainActor
final class PlaybackViewModelTests: XCTestCase {

    var sut: PlaybackViewModel!

    override func setUp() {
        super.setUp()
        sut = PlaybackViewModel()
    }

    override func tearDown() {
        sut.stopPlayback()
        sut = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func test_initialState_isLoading() {
        XCTAssertTrue(sut.isLoading)
    }

    func test_initialState_isNotPlaying() {
        XCTAssertFalse(sut.isPlaying)
    }

    func test_initialState_storyIsEmpty() {
        XCTAssertEqual(sut.story, "")
    }

    func test_initialState_noErrorMessage() {
        XCTAssertNil(sut.errorMessage)
    }

    // MARK: - stopPlayback

    func test_stopPlayback_setsIsPlayingFalse() {
        sut.isPlaying = true
        sut.stopPlayback()
        XCTAssertFalse(sut.isPlaying)
    }

    func test_stopPlayback_whenAlreadyStopped_remainsFalse() {
        sut.stopPlayback()
        XCTAssertFalse(sut.isPlaying)
    }

    // MARK: - togglePlayback

    func test_togglePlayback_whenStory_togglesIsPlaying() {
        sut.story = "Hi Harri, it's Jane."
        sut.isLoading = false

        sut.togglePlayback()
        XCTAssertTrue(sut.isPlaying)

        sut.togglePlayback()
        XCTAssertFalse(sut.isPlaying)
    }

    func test_togglePlayback_multipleTogglesCycleCorrectly() {
        sut.story = "Some story."
        sut.isLoading = false

        for i in 1...4 {
            sut.togglePlayback()
            XCTAssertEqual(sut.isPlaying, i.isMultiple(of: 2) == false,
                           "After \(i) toggle(s), isPlaying should be \(i.isMultiple(of: 2) == false)")
        }
    }

    // MARK: - loadStory (with no API key — fallback path)

    func test_loadStory_withNoAPIKey_setsFallbackStory() async {
        let member = FamilyMember.mockData[0] // Jane
        await sut.loadStory(for: member, userName: "Harri")

        XCTAssertFalse(sut.isLoading)
        XCTAssertFalse(sut.story.isEmpty)
        // Should contain the user name and member name in some form
        XCTAssertTrue(
            sut.story.localizedCaseInsensitiveContains("Harri") ||
            sut.story.localizedCaseInsensitiveContains("Jane"),
            "Fallback story should mention Harri or Jane — got: \(sut.story)"
        )
    }

    func test_loadStory_setsIsLoadingFalseWhenDone() async {
        let member = FamilyMember.mockData[1]
        await sut.loadStory(for: member, userName: "Harri")
        XCTAssertFalse(sut.isLoading)
    }

    func test_loadStory_isNotPlayingAfterLoad() async {
        let member = FamilyMember.mockData[2]
        await sut.loadStory(for: member, userName: "Harri")
        XCTAssertFalse(sut.isPlaying)
    }

    func test_loadStory_differentMembers_produceDifferentFallbacks() async {
        let member1 = FamilyMember.mockData[0] // Jane
        let member2 = FamilyMember.mockData[1] // Michael

        let vm1 = PlaybackViewModel()
        let vm2 = PlaybackViewModel()

        await vm1.loadStory(for: member1, userName: "Harri")
        await vm2.loadStory(for: member2, userName: "Harri")

        // Fallback stories should mention different names
        XCTAssertNotEqual(vm1.story, vm2.story)
    }
}
