import XCTest
@testable import MeowxCore

final class SettingsPhaseTests: XCTestCase {
    func testOldSettingsKeepTheNewDefaults() throws {
        let settings = try JSONDecoder().decode(PlayerSettings.self, from: Data(#"{"cacheMegabytes":64}"#.utf8))
        XCTAssertEqual(settings.appearance, .dark)
        XCTAssertTrue(settings.resumeOnOpen)
        XCTAssertTrue(settings.playNext)
        XCTAssertEqual(settings.endBehavior, .off)
        XCTAssertEqual(settings.speedStep, .ladder)
        XCTAssertEqual(settings.seekShort, 5, accuracy: 0.001)
        XCTAssertEqual(settings.seekMedium, 10, accuracy: 0.001)
        XCTAssertEqual(settings.seekLong, 30, accuracy: 0.001)
        XCTAssertEqual(settings.toneMapping, .auto)
        XCTAssertTrue(settings.screenshotWithSubtitles)
        XCTAssertEqual(settings.audioDevice, "auto")
        XCTAssertFalse(settings.loudnessNormalize)
        XCTAssertTrue(settings.rememberVolume)
        XCTAssertEqual(settings.shortcutOverrides, [:])
        let again = try JSONDecoder().decode(PlayerSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(again, settings)
        XCTAssertEqual(PlayerSettings.clampedSeek(0), 1, accuracy: 0.001)
        XCTAssertEqual(PlayerSettings.clampedSeek(400), 120, accuracy: 0.001)
    }

    func testSpeedStepsAndEndChoice() {
        XCTAssertEqual(SpeedStep.ladder.nudged(1, direction: 1), 1.25, accuracy: 0.001)
        XCTAssertEqual(SpeedStep.tenth.nudged(1, direction: -1), 0.9, accuracy: 0.001)
        XCTAssertEqual(SpeedStep.quarter.nudged(3.9, direction: 1), 4, accuracy: 0.001)
        XCTAssertFalse(EndChoice.shouldAdvance(playNext: false, repeatMode: .off))
        XCTAssertTrue(EndChoice.shouldAdvance(playNext: false, repeatMode: .one))
        XCTAssertTrue(EndChoice.shouldAdvance(playNext: true, repeatMode: .off))
        XCTAssertEqual(AudioChain.filter(normalize: true, compress: true), "dynaudnorm,lavfi=[acompressor]")
        XCTAssertEqual(AudioChain.filter(normalize: false, compress: false), "")
    }

    func testShortcutOverridesWinAndConflictsAreNamed() {
        let overrides = ["playPause": KeyBinding(token: "q")]
        XCTAssertEqual(ShortcutMap.match(ShortcutInput(token: "q"), overrides: overrides)?.id, "playPause")
        XCTAssertNil(ShortcutMap.match(ShortcutInput(token: "space"), overrides: overrides))
        XCTAssertEqual(ShortcutMap.owner(of: ShortcutInput(token: "q"), overrides: overrides, ignoring: "mute"), "Play or pause")
        XCTAssertNil(ShortcutMap.owner(of: ShortcutInput(token: "q"), overrides: overrides, ignoring: "playPause"))
        XCTAssertEqual(ShortcutMap.match(ShortcutInput(token: "space"), overrides: [:])?.id, "playPause")
    }
}
