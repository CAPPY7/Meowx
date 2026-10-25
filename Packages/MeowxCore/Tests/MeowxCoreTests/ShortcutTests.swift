import XCTest
@testable import MeowxCore

final class ShortcutTests: XCTestCase {
    func testNoTwoCommandsShareAKey() {
        let keyed = ShortcutCatalog.all.filter { !$0.token.isEmpty }
        let combos = keyed.map(\.combo)
        XCTAssertEqual(Set(combos).count, combos.count, combos.joined(separator: ", "))
    }

    func testMatchAgreesWithDisplay() {
        let space = ShortcutCatalog.match(ShortcutInput(token: "space"))
        XCTAssertEqual(space?.id, "playPause")
        XCTAssertEqual(space?.display, "Space")
        XCTAssertEqual(ShortcutCatalog.help("playPause", title: "Pause"), "Pause (Space)")

        let previous = ShortcutCatalog.match(ShortcutInput(token: "left", command: true))
        XCTAssertEqual(previous?.id, "previous")
        XCTAssertEqual(previous?.display, "Cmd+Left")

        let bigSeek = ShortcutCatalog.match(ShortcutInput(token: "left", shift: true))
        XCTAssertEqual(bigSeek?.id, "seekBack30")

        let shot = ShortcutCatalog.match(ShortcutInput(token: "s", command: true, shift: true))
        XCTAssertEqual(shot?.id, "screenshot")
        XCTAssertEqual(shot?.display, "Shift+Cmd+S")

        XCTAssertNil(ShortcutCatalog.match(ShortcutInput(token: "s", option: true)))
        XCTAssertNil(ShortcutCatalog.match(ShortcutInput(token: "left", command: true, shift: true)))

        XCTAssertEqual(ShortcutCatalog.match(ShortcutInput(token: "z"))?.id, "subDelayEarlier")
        XCTAssertEqual(ShortcutCatalog.match(ShortcutInput(token: "z", option: true))?.id, "audioDelayEarlier")
        XCTAssertEqual(ShortcutCatalog.match(ShortcutInput(token: "s", shift: true))?.id, "previousSubtitle")
        XCTAssertEqual(ShortcutCatalog.match(ShortcutInput(token: "1"))?.id, "jump1")
        XCTAssertEqual(ShortcutCatalog.match(ShortcutInput(token: "1", command: true))?.id, "windowHalf")
        XCTAssertEqual(ShortcutCatalog.match(ShortcutInput(token: "f", command: true, control: true))?.id, "fullScreenSystem")
        XCTAssertEqual(ShortcutCatalog.match(ShortcutInput(token: "f", command: true, control: true))?.display, "Ctrl+Cmd+F")
        XCTAssertEqual(ShortcutKey.token(for: 6), "z")
        XCTAssertEqual(ShortcutKey.token(for: 115), "home")
        XCTAssertEqual(ShortcutKey.token(for: 18), "1")
        XCTAssertNil(ShortcutKey.token(for: 116))
    }

    func testTextAndPlaybackDecisions() {
        XCTAssertTrue(KeyRouting(appModal: false, sheetAttached: true, firstResponderIsText: false).leaveEventForText)
        XCTAssertTrue(KeyRouting(appModal: true, sheetAttached: false, firstResponderIsText: false).leaveEventForText)
        XCTAssertTrue(KeyRouting(appModal: false, sheetAttached: false, firstResponderIsText: true).leaveEventForText)
        XCTAssertFalse(KeyRouting(appModal: false, sheetAttached: false, firstResponderIsText: false).leaveEventForText)

        XCTAssertEqual(PlaybackJump.seconds(digit: 0, duration: 100), Optional(0.0))
        XCTAssertEqual(PlaybackJump.seconds(digit: 3, duration: 200), Optional(60.0))
        XCTAssertNil(PlaybackJump.seconds(digit: 3, duration: 0))
        XCTAssertNil(PlaybackJump.seconds(digit: 10, duration: 100))

        XCTAssertEqual(LoopCycle.next(hasA: false, hasB: false), .setA)
        XCTAssertEqual(LoopCycle.next(hasA: true, hasB: false), .setB)
        XCTAssertEqual(LoopCycle.next(hasA: true, hasB: true), .clear)
        XCTAssertEqual(LoopCycle.next(hasA: false, hasB: true), .setA)

        XCTAssertEqual(AspectCycle.next(current: ""), "16:9")
        XCTAssertEqual(AspectCycle.next(current: "no"), "16:9")
        XCTAssertEqual(AspectCycle.next(current: "1:1"), "")
        XCTAssertEqual(AspectCycle.mpvValue(""), "no")
        XCTAssertEqual(AspectCycle.label("4:3"), "Aspect: 4:3")

        XCTAssertEqual(RotationCycle.next(degrees: 0), 90)
        XCTAssertEqual(RotationCycle.next(degrees: 270), 0)
        XCTAssertEqual(RotationCycle.next(degrees: -90), 0)

        let half = WindowFit.scaled(videoWidth: 1920, videoHeight: 1080, scale: 0.5, maxWidth: 3000, maxHeight: 2000)
        XCTAssertEqual(half, FrameSize(width: 960, height: 540) as FrameSize?)
        let clamped = WindowFit.scaled(videoWidth: 1920, videoHeight: 1080, scale: 2, maxWidth: 1000, maxHeight: 800)
        XCTAssertEqual(clamped, FrameSize(width: 1000, height: 563) as FrameSize?)
        XCTAssertNil(WindowFit.fitted(videoWidth: 0, videoHeight: 1080, maxWidth: 1000, maxHeight: 800))
    }

    func testTrackLabelIncludesCodecChannelsAndTags() {
        let line = TrackLabel.text(
            kind: "audio",
            id: 1,
            language: "English",
            title: "",
            codec: "ac3",
            channels: "5.1",
            isDefault: true,
            isExternal: false,
            isForced: false,
            albumArt: false
        )
        XCTAssertEqual(line, "English - AC3 5.1 (default)")

        let sub = TrackLabel.text(
            kind: "sub",
            id: 4,
            language: "",
            title: "",
            codec: "",
            channels: "",
            isDefault: false,
            isExternal: true,
            isForced: true,
            albumArt: false
        )
        XCTAssertEqual(sub, "Subtitle 4 (external, forced)")
    }
}
