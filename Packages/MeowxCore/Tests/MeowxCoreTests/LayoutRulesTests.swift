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

    func testThumbnailCacheKeyIsStable() {
        let first = ThumbnailCache.key(path: "/films/one.mkv", fileSize: 10)
        XCTAssertEqual(first, ThumbnailCache.key(path: "/films/one.mkv", fileSize: 10))
        XCTAssertNotEqual(first, ThumbnailCache.key(path: "/films/one.mkv", fileSize: 11))
        XCTAssertEqual(first.count, 16)
    }
}
