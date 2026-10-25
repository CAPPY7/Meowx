import XCTest
@testable import MeowxCore

final class PointerTests: XCTestCase {
    func testSingleClickPausesAndDoubleClickDoesNot() {
        var click = PendingClick()
        click.firstClick(pauseEnabled: true)
        XCTAssertEqual(click.fireIfStillPending(), .togglePause)

        click.firstClick(pauseEnabled: true)
        XCTAssertEqual(click.secondClick(), .toggleFullScreen)
        XCTAssertEqual(click.fireIfStillPending(), .none)

        click.firstClick(pauseEnabled: true)
        XCTAssertEqual(click.secondClick(zone: .leading, sideSeekEnabled: true), .seekBackward)
        XCTAssertEqual(click.secondClick(zone: .trailing, sideSeekEnabled: true), .seekForward)
        XCTAssertEqual(click.secondClick(zone: .leading, sideSeekEnabled: false), .toggleFullScreen)

        click.firstClick(pauseEnabled: false)
        XCTAssertEqual(click.fireIfStillPending(), .none)
        click.firstClick(pauseEnabled: true)
        click.dragged()
        XCTAssertEqual(click.fireIfStillPending(), .none)
    }

    func testScrollIgnoresMomentumAndPicksOneAxis() {
        let momentum = ScrollAction.interpret(deltaX: 0, deltaY: 4, precise: false, momentum: true, volumeEnabled: true, seekEnabled: true)
        XCTAssertEqual(momentum, ScrollAction(volumeDelta: 0, seekDelta: 0))

        let wheel = ScrollAction.interpret(deltaX: 0.1, deltaY: 1, precise: false, momentum: false, volumeEnabled: true, seekEnabled: true)
        XCTAssertEqual(wheel.volumeDelta, 5, accuracy: 0.001)
        XCTAssertEqual(wheel.seekDelta, 0, accuracy: 0.001)

        let sideways = ScrollAction.interpret(deltaX: 2, deltaY: 0, precise: false, momentum: false, volumeEnabled: true, seekEnabled: true)
        XCTAssertEqual(sideways.seekDelta, 10, accuracy: 0.001)

        let off = ScrollAction.interpret(deltaX: 0, deltaY: 3, precise: false, momentum: false, volumeEnabled: false, seekEnabled: true)
        XCTAssertEqual(off.volumeDelta, 0, accuracy: 0.001)

        let pad = ScrollAction.interpret(deltaX: 0, deltaY: 20, precise: true, momentum: false, volumeEnabled: true, seekEnabled: true)
        XCTAssertEqual(pad.volumeDelta, 5, accuracy: 0.001)
    }

    func testTimeJumpParsesClockAndSeconds() {
        XCTAssertEqual(TimeJump.seconds(from: "90") ?? -1, 90, accuracy: 0.001)
        XCTAssertEqual(TimeJump.seconds(from: "1:23") ?? -1, 83, accuracy: 0.001)
        XCTAssertEqual(TimeJump.seconds(from: "1:02:03") ?? -1, 3723, accuracy: 0.001)
        XCTAssertNil(TimeJump.seconds(from: "1:90"))
        XCTAssertNil(TimeJump.seconds(from: ""))
        XCTAssertNil(TimeJump.seconds(from: "nope"))
    }

    func testPointerSettingsSurviveOldFiles() throws {
        let settings = try JSONDecoder().decode(PlayerSettings.self, from: Data(#"{"cacheMegabytes":64}"#.utf8))
        XCTAssertTrue(settings.clickToPause)
        XCTAssertTrue(settings.scrollAdjustsVolume)
        XCTAssertTrue(settings.scrollSeeks)
        XCTAssertTrue(settings.doubleClickSidesSeek)
        XCTAssertFalse(settings.showRemainingTime)
    }
}
