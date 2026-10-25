import XCTest
@testable import MeowxCore

final class ChromeTests: XCTestCase {
    func testDefaultsHideChromeAfterThreeSeconds() {
        let settings = PlayerSettings.default
        XCTAssertTrue(settings.hideChromeWhilePlaying)
        XCTAssertEqual(settings.chromeHideDelay, 3, accuracy: 0.001)
    }

    func testOldSettingsFileKeepsNewKeysAtDefaults() throws {
        let json = """
        {"hardwareDecoding":false,"subtitleLanguage":"en","audioLanguage":"ja","cacheMegabytes":128,"screenshotFolder":"/tmp/shots","screenshotFormat":"jpg","subtitleFont":"Avenir","subtitleSize":40,"subtitleColorHex":"#FFFFFF","subtitlePosition":90,"openSubtitlesAPIKey":"key"}
        """
        let settings = try JSONDecoder().decode(PlayerSettings.self, from: Data(json.utf8))
        XCTAssertFalse(settings.hardwareDecoding)
        XCTAssertEqual(settings.subtitleLanguage, "en")
        XCTAssertEqual(settings.cacheMegabytes, 128)
        XCTAssertEqual(settings.screenshotFormat, .jpg)
        XCTAssertEqual(settings.subtitleSize, 40, accuracy: 0.001)
        XCTAssertTrue(settings.hideChromeWhilePlaying)
        XCTAssertEqual(settings.chromeHideDelay, 3, accuracy: 0.001)
        XCTAssertTrue(settings.quitWhenWindowCloses)
        XCTAssertFalse(settings.resizeToVideoOnOpen)
        XCTAssertFalse(settings.playlistOpen)
        let again = try JSONDecoder().decode(PlayerSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(again, settings)
    }

    func testHideDelayIsClamped() throws {
        let json = #"{"chromeHideDelay":0.2,"hideChromeWhilePlaying":false}"#
        let settings = try JSONDecoder().decode(PlayerSettings.self, from: Data(json.utf8))
        XCTAssertFalse(settings.hideChromeWhilePlaying)
        XCTAssertEqual(settings.chromeHideDelay, 1, accuracy: 0.001)
        XCTAssertEqual(PlayerSettings.clampedHideDelay(40), 10, accuracy: 0.001)
    }

    func testChromeStaysForAudioPauseErrorsAndRecentMouse() {
        var state = playing()
        XCTAssertFalse(state.visible)

        state.paused = true
        XCTAssertTrue(state.visible)
        state.paused = false
        XCTAssertFalse(state.visible)

        state.mediaLoaded = false
        XCTAssertTrue(state.visible)
        state.mediaLoaded = true

        state.hasVideo = false
        XCTAssertTrue(state.visible)
        state.hasVideo = true

        state.scrubbing = true
        XCTAssertTrue(state.visible)
        state.scrubbing = false

        state.pointerOverControls = true
        XCTAssertTrue(state.visible)
        state.pointerOverControls = false

        state.overlayOpen = true
        XCTAssertTrue(state.visible)
        state.overlayOpen = false

        state.showingError = true
        XCTAssertTrue(state.visible)
        state.showingError = false

        state.secondsSinceActivity = 2
        XCTAssertTrue(state.visible)
        state.secondsSinceActivity = 3
        XCTAssertFalse(state.visible)

        state.autoHideEnabled = false
        state.secondsSinceActivity = 100
        XCTAssertTrue(state.visible)
    }

    private func playing() -> ChromeState {
        ChromeState(
            autoHideEnabled: true,
            paused: false,
            mediaLoaded: true,
            hasVideo: true,
            scrubbing: false,
            pointerOverControls: false,
            overlayOpen: false,
            secondsSinceActivity: 9,
            hideAfter: 3,
            showingError: false
        )
    }
}
