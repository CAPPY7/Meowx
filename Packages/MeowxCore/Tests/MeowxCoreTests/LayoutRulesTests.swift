import XCTest
@testable import MeowxCore

final class LayoutRulesTests: XCTestCase {
    func testPlaylistStaysOnlyWhileOpenAndChromeOrPointer() {
        XCTAssertFalse(PlaylistPanel.visible(open: false, chromeVisible: true, pointerInside: true))
        XCTAssertTrue(PlaylistPanel.visible(open: true, chromeVisible: true, pointerInside: false))
        XCTAssertTrue(PlaylistPanel.visible(open: true, chromeVisible: false, pointerInside: true))
        XCTAssertFalse(PlaylistPanel.visible(open: true, chromeVisible: false, pointerInside: false))
    }

    func testPlaylistSearchMatchesTitleOrFileName() {
        let items = [
            PlaylistItem(url: URL(fileURLWithPath: "/films/one.mkv"), title: "Arrival"),
            PlaylistItem(url: URL(fileURLWithPath: "/films/two.mp4"), title: "Contact")
        ]
        XCTAssertEqual(PlaylistQuery.filter(items, query: "  ").count, 2)
        XCTAssertEqual(PlaylistQuery.filter(items, query: "arr").map(\.title), ["Arrival"])
        XCTAssertEqual(PlaylistQuery.filter(items, query: "TWO").map(\.title), ["Contact"])
        XCTAssertTrue(PlaylistQuery.filter(items, query: "nope").isEmpty)
    }

    func testTrafficClearanceUsesTheButtonFrame() {
        XCTAssertEqual(TrafficClearance.inset(buttonMaxX: 62, fullscreen: false), 70, accuracy: 0.001)
        XCTAssertEqual(TrafficClearance.inset(buttonMaxX: 62, fullscreen: true), 0, accuracy: 0.001)
        XCTAssertEqual(TrafficClearance.inset(buttonMaxX: 0, fullscreen: false), 0, accuracy: 0.001)
        XCTAssertEqual(TrafficClearance.inset(buttonMaxX: .nan, fullscreen: false), 0, accuracy: 0.001)
    }

    func testHDRBadgeAndMediaLine() {
        XCTAssertTrue(HDRBadge.isHDR(gamma: "pq", primaries: "bt.709"))
        XCTAssertTrue(HDRBadge.isHDR(gamma: "HLG", primaries: ""))
        XCTAssertTrue(HDRBadge.isHDR(gamma: "gamma2.2", primaries: "bt.2020"))
        XCTAssertFalse(HDRBadge.isHDR(gamma: "bt.1886", primaries: "bt.709"))
        XCTAssertEqual(MediaLine.detail(width: 1920, height: 1080, codec: "hevc"), "1920×1080 · hevc")
        XCTAssertEqual(MediaLine.detail(width: 0, height: 0, codec: "  "), "")
        XCTAssertEqual(MediaLine.detail(width: 1280, height: 720, codec: ""), "1280×720")
    }

    func testVolumeKnobSitsOnTheLevel() {
        XCTAssertEqual(VolumeTrack.fraction(volume: 100, muted: false), 0.5, accuracy: 0.001)
        XCTAssertEqual(VolumeTrack.fraction(volume: 250, muted: false), 1, accuracy: 0.001)
        XCTAssertEqual(VolumeTrack.fraction(volume: 80, muted: true), 0, accuracy: 0.001)
        XCTAssertEqual(VolumeTrack.knobCenter(fraction: 0.5, width: 100, knob: 12), 50, accuracy: 0.001)
        XCTAssertEqual(VolumeTrack.knobCenter(fraction: 0, width: 100, knob: 12), 6, accuracy: 0.001)
        XCTAssertEqual(VolumeTrack.knobCenter(fraction: 1, width: 100, knob: 12), 94, accuracy: 0.001)
    }

    func testOldSubtitleSizeIsBroughtDown() {
        XCTAssertEqual(SubtitleStyle.migrated(size: 55, outline: 1).size, 36, accuracy: 0.001)
        XCTAssertEqual(SubtitleStyle.migrated(size: 55, outline: 1).outline, 2, accuracy: 0.001)
        XCTAssertEqual(SubtitleStyle.migrated(size: 48, outline: 1).size, 48, accuracy: 0.001)
        XCTAssertEqual(OpeningCue.seconds, 4, accuracy: 0.001)
    }

    func testBufferAndClock() {
        let span = BufferSpan.fractions(position: 10, cachedAhead: 5, duration: 100)
        XCTAssertEqual(span.played, 0.1, accuracy: 0.001)
        XCTAssertEqual(span.bufferStart, 0.1, accuracy: 0.001)
        XCTAssertEqual(span.bufferEnd, 0.15, accuracy: 0.001)
        XCTAssertEqual(BufferSpan.fractions(position: 0, cachedAhead: 0, duration: 0).played, 0, accuracy: 0.001)
        XCTAssertEqual(TimeReadout.seconds(position: 40, duration: 100, remaining: false), 100, accuracy: 0.001)
        XCTAssertEqual(TimeReadout.seconds(position: 40, duration: 100, remaining: true), 60, accuracy: 0.001)
        XCTAssertEqual(PictureZone.at(x: 10, width: 300), .leading)
        XCTAssertEqual(PictureZone.at(x: 150, width: 300), .center)
        XCTAssertEqual(PictureZone.at(x: 250, width: 300), .trailing)
        XCTAssertEqual(PictureZone.at(x: 10, width: 0), .center)
        XCTAssertEqual(SpeedPresets.values, [0.5, 0.75, 1, 1.25, 1.5, 2, 3, 4])
    }

    func testThumbnailCacheKeyIsStable() {
        let first = ThumbnailCache.key(path: "/films/one.mkv", fileSize: 10)
        XCTAssertEqual(first, ThumbnailCache.key(path: "/films/one.mkv", fileSize: 10))
        XCTAssertNotEqual(first, ThumbnailCache.key(path: "/films/one.mkv", fileSize: 11))
        XCTAssertEqual(first.count, 16)
    }
}
