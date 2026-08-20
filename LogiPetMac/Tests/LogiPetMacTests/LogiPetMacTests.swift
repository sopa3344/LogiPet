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

    @MainActor
    func testPixelTextMeasuresKoreanContentWithinItsConstraint() {
        FontRegistry.registerBundledFonts()
        let view = PixelTextView()
        view.configure(
            text: "오늘 클릭을 21번 했어!",
            size: 9,
            color: .labelColor,
            lineLimit: 2,
            alignment: .left,
            underline: false
        )

        let measured = view.measure(maxWidth: 96)
        XCTAssertGreaterThan(measured.width, 0)
        XCTAssertLessThanOrEqual(measured.width, 96)
        XCTAssertGreaterThan(measured.height, 0)
    }
}
