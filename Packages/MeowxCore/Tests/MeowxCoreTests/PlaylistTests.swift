import XCTest
@testable import MeowxCore

final class PlaylistTests: XCTestCase {
    private func item(_ name: String) -> PlaylistItem {
        PlaylistItem(url: URL(fileURLWithPath: "/tmp/\(name).mp4"), title: name)
    }

    func testAppendSelectsFirstWhenEmpty() {
        var playlist = Playlist()
        let first = item("a")
        playlist.append([first, item("b")])
        XCTAssertEqual(playlist.current?.id, first.id)
        XCTAssertEqual(playlist.items.count, 2)
    }

    func testSkipAndRepeatAll() {
        var playlist = Playlist()
        playlist.append([item("a"), item("b"), item("c")])
        XCTAssertEqual(playlist.skipped(by: 1)?.title, "b")
        XCTAssertEqual(playlist.skipped(by: 1)?.title, "c")
        XCTAssertNil(playlist.skipped(by: 1))
        XCTAssertEqual(playlist.current?.title, "c")
        playlist.repeatMode = .all
        XCTAssertEqual(playlist.skipped(by: 1)?.title, "a")
    }

    func testEndOfFileRepeatOneStays() {
        var playlist = Playlist()
        playlist.append([item("a"), item("b")])
        playlist.repeatMode = .one
        guard case .play(let item) = playlist.afterEndOfFile() else {
            return XCTFail("expected replay")
        }
        XCTAssertEqual(item.title, "a")
        XCTAssertEqual(playlist.current?.title, "a")
    }

    func testEndOfFileStopsThenWraps() {
        var playlist = Playlist()
        playlist.append([item("a"), item("b")])
        XCTAssertEqual(playlist.skipped(by: 1)?.title, "b")
        XCTAssertEqual(playlist.afterEndOfFile(), .stop)
        playlist.repeatMode = .all
        guard case .play(let item) = playlist.afterEndOfFile() else {
            return XCTFail("expected wrap")
        }
        XCTAssertEqual(item.title, "a")
    }

    func testManualSkipDoesNotStickOnRepeatOne() {
        var playlist = Playlist()
        playlist.append([item("a"), item("b")])
        playlist.repeatMode = .one
        XCTAssertEqual(playlist.skipped(by: 1)?.title, "b")
    }

    func testRemoveCurrentSelectsNeighbor() {
        var playlist = Playlist()
        let a = item("a")
        let b = item("b")
        let c = item("c")
        playlist.append([a, b, c])
        playlist.select(id: b.id)
        playlist.remove(id: b.id)
        XCTAssertEqual(playlist.current?.id, c.id)
        playlist.remove(id: a.id)
        XCTAssertEqual(playlist.current?.id, c.id)
    }

    func testMoveKeepsCurrentItem() {
        var playlist = Playlist()
        let a = item("a")
        let b = item("b")
        let c = item("c")
        playlist.append([a, b, c])
        playlist.select(id: a.id)
        playlist.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        XCTAssertEqual(playlist.items.map(\.title), ["b", "c", "a"])
        XCTAssertEqual(playlist.current?.title, "a")
    }

    func testShuffleKeepsMembershipAndCurrent() {
        var playlist = Playlist()
        playlist.append([item("a"), item("b"), item("c"), item("d")])
        let current = playlist.current?.id
        var generator = SplitMix64(state: 7)
        playlist.setShuffle(true, using: &generator)
        playlist.repeatMode = .all
        XCTAssertEqual(playlist.current?.id, current)
        var seen = Set<UUID>()
        var cursor = playlist.current
        for _ in 0..<4 {
            guard let current = cursor else { return XCTFail("missing item") }
            seen.insert(current.id)
            cursor = playlist.skipped(by: 1)
        }
        XCTAssertEqual(seen.count, 4)
    }

    func testM3URoundTrip() throws {
        let base = URL(fileURLWithPath: "/tmp/lists", isDirectory: true)
        let text = """
        #EXTM3U
        #EXTINF:-1,One
        one.mp4
        # a comment
        #EXTINF:-1,Stream
        https://example.com/a.m3u8

        """
        let parsed = Playlist.parseM3U(text, relativeTo: base)
        XCTAssertEqual(parsed.count, 2)
        XCTAssertEqual(parsed[0].title, "One")
        XCTAssertEqual(parsed[0].url.path, "/tmp/lists/one.mp4")
        XCTAssertEqual(parsed[1].url.absoluteString, "https://example.com/a.m3u8")
        var playlist = Playlist()
        playlist.append(parsed)
        let exported = Playlist.parseM3U(playlist.m3uText(), relativeTo: nil)
        XCTAssertEqual(exported.map(\.title), ["One", "Stream"])
    }
}

struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
