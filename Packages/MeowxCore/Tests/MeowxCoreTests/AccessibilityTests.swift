import XCTest
@testable import MeowxCore

final class AccessibilityTests: XCTestCase {
    func testPaintFallsBackForContrastAndMotion() {
        XCTAssertFalse(AccessibilityPaint.usesSolidSurface(reduceTransparency: false, increaseContrast: false))
        XCTAssertTrue(AccessibilityPaint.usesSolidSurface(reduceTransparency: true, increaseContrast: false))
        XCTAssertTrue(AccessibilityPaint.usesSolidSurface(reduceTransparency: false, increaseContrast: true))
        XCTAssertEqual(AccessibilityPaint.ringWidth(increaseContrast: false), 1, accuracy: 0.001)
        XCTAssertEqual(AccessibilityPaint.ringWidth(increaseContrast: true), 2, accuracy: 0.001)
        XCTAssertEqual(AccessibilityPaint.fade(reduceMotion: false), 0.18, accuracy: 0.001)
        XCTAssertEqual(AccessibilityPaint.fade(reduceMotion: true), 0, accuracy: 0.001)
    }

    func testCursorHideDoesNotImmediatelyReopenChrome() {
        let hidden = Date(timeIntervalSince1970: 100)
        XCTAssertTrue(CursorChrome.shouldIgnoreActivity(hiddenAt: hidden, now: hidden.addingTimeInterval(0.05)))
        XCTAssertFalse(CursorChrome.shouldIgnoreActivity(hiddenAt: hidden, now: hidden.addingTimeInterval(0.2)))
        XCTAssertFalse(CursorChrome.shouldIgnoreActivity(hiddenAt: nil, now: hidden))
    }

    func testPointerJitterDoesNotCountAsActivity() {
        XCTAssertTrue(PointerActivity.moved(from: nil, to: (0, 0)))
        XCTAssertFalse(PointerActivity.moved(from: (0, 0), to: (2, 2)))
        XCTAssertTrue(PointerActivity.moved(from: (0, 0), to: (8, 1)))
    }

    func testTickSkipsUnchangedValues() {
        XCTAssertFalse(TickGate.shouldWrite(10.0, 10.02, epsilon: 0.05))
        XCTAssertTrue(TickGate.shouldWrite(10.0, 10.2, epsilon: 0.05))
        XCTAssertFalse(TickGate.shouldWrite("h264", "h264"))
        XCTAssertTrue(TickGate.shouldWrite(false, true))
    }

    func testSeekValueIncludesTheChapter() {
        XCTAssertEqual(SeekAccess.value(position: 62, duration: 600, chapterTitle: nil), "1:02 of 10:00")
        XCTAssertEqual(SeekAccess.value(position: 62, duration: 600, chapterTitle: "Garden"), "1:02 of 10:00, Garden")
        XCTAssertEqual(SeekAccess.value(position: 62, duration: 600, chapterTitle: "  "), "1:02 of 10:00")
    }
}
