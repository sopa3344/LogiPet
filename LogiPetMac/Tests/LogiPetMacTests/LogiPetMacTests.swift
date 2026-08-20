import XCTest
@testable import LogiPetMac

final class LogiPetMacTests: XCTestCase {
    func testDailyStateResetsOldCounts() {
        var state = DailyState(date: "2000-01-01", leftClicks: 5, rightClicks: 4,
                               middleClicks: 3, actionRingActions: 2, wheelTurns: 1)
        state.ensureToday()
        XCTAssertEqual(state.date, DailyState.todayKey)
        XCTAssertEqual(state.leftClicks, 0)
        XCTAssertEqual(state.actionRingActions, 0)
    }

    func testBundledResourcesCanBeLocated() {
        XCTAssertNotNil(ResourceLocator.url(
            forResource: "Galmuri11",
            withExtension: "ttf",
            subdirectory: "Resources/Fonts"
        ))
        XCTAssertNotNil(ResourceLocator.url(
            forResource: "Golden-Retriever-idle",
            withExtension: "png",
            subdirectory: "Resources/Pets/GoldenRetriever"
        ))
    }
}
