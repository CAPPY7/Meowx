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
