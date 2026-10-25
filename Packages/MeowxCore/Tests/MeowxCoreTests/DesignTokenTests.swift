import XCTest
@testable import MeowxCore

final class DesignTokenTests: XCTestCase {
    func testBrandColorsMatchTheIconPack() {
        XCTAssertEqual(DesignTokens.violet, RGB(red: 106.0 / 255, green: 69.0 / 255, blue: 1))
        XCTAssertEqual(DesignTokens.indigo, RGB(red: 22.0 / 255, green: 14.0 / 255, blue: 74.0 / 255))
        XCTAssertEqual(DesignTokens.cyan, RGB(red: 34.0 / 255, green: 211.0 / 255, blue: 238.0 / 255))
        XCTAssertEqual(DesignTokens.magenta, RGB(red: 224.0 / 255, green: 64.0 / 255, blue: 251.0 / 255))
        XCTAssertGreaterThan(DesignTokens.success.green, DesignTokens.success.red)
        XCTAssertGreaterThan(DesignTokens.warning.red, DesignTokens.warning.blue)
    }

    func testSpacingIsAnEightPointGridAndTypeIsFixed() {
        XCTAssertEqual(DesignTokens.spaces, [4, 8, 12, 16, 24, 32])
        XCTAssertTrue(DesignTokens.spaces.allSatisfy { $0.truncatingRemainder(dividingBy: 4) == 0 })
        XCTAssertEqual(DesignTokens.radiusSmall, 10)
        XCTAssertEqual(DesignTokens.radiusMedium, 16)
        XCTAssertEqual(DesignTokens.radiusLarge, 24)
        XCTAssertEqual(DesignTokens.title, 20)
        XCTAssertEqual(DesignTokens.body, 13)
        XCTAssertEqual(DesignTokens.caption, 11)
        XCTAssertEqual(DesignTokens.hit, 28)
        XCTAssertEqual(DesignTokens.springResponse, 0.3)
        XCTAssertEqual(DesignTokens.springDamping, 0.85)
        XCTAssertEqual(DesignTokens.fade, 0.18)
    }

    func testReduceMotionRemovesAnimation() {
        XCTAssertEqual(DesignTokens.duration(0.18, reduceMotion: true), 0)
        XCTAssertEqual(DesignTokens.duration(0.3, reduceMotion: false), 0.3)
        XCTAssertEqual(DesignTokens.duration(-1, reduceMotion: false), 0)
    }
}
