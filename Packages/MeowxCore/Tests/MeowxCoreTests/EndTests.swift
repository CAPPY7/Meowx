import XCTest
@testable import MeowxCore

final class EndTests: XCTestCase {
    private func item(_ name: String) -> PlaylistItem {
        PlaylistItem(url: URL(fileURLWithPath: "/tmp/\(name).mp4"), title: name)
    }

    func testEndGateDropsASecondSignalUntilPlaybackMoves() {
        var gate = EndOfFileGate()
        XCTAssertTrue(gate.consume(reached: true))
        XCTAssertFalse(gate.consume(reached: true))
        gate.noteProgress(position: 99, duration: 100)
        XCTAssertFalse(gate.consume(reached: true))
        gate.noteProgress(position: 10, duration: 100)
        XCTAssertTrue(gate.consume(reached: true))
        XCTAssertFalse(gate.consume(reached: false))
        gate.fileDidLoad()
        XCTAssertTrue(gate.consume(reached: true))
    }

    func testLastItemStopsAndRepeatOneDoesNotSkip() {
        var playlist = Playlist()
        playlist.append([item("a"), item("b")])
        guard case .play(let next) = playlist.afterEndOfFile() else {
            return XCTFail("expected next")
        }
        XCTAssertEqual(next.title, "b")
        XCTAssertEqual(playlist.afterEndOfFile(), .stop)
        playlist.repeatMode = .one
        guard case .play(let same) = playlist.afterEndOfFile() else {
            return XCTFail("expected replay")
        }
        XCTAssertEqual(same.title, "b")
        XCTAssertEqual(playlist.current?.title, "b")
    }

    func testShuffleEndDoesNotRepeatItems() {
        var playlist = Playlist()
        playlist.append([item("a"), item("b"), item("c"), item("d")])
        var generator = SplitMix64(state: 3)
        playlist.setShuffle(true, using: &generator)
        var seen: [String] = []
        for _ in 0..<8 {
            guard let title = playlist.current?.title else {
                return XCTFail("missing item")
            }
            seen.append(title)
            if playlist.afterEndOfFile() == .stop { break }
        }
        XCTAssertEqual(seen.count, Set(seen).count)
        XCTAssertLessThanOrEqual(seen.count, 4)
        XCTAssertFalse(seen.isEmpty)
    }

    func testRepeatAllWrapsOncePerEnding() {
        var playlist = Playlist()
        playlist.append([item("a"), item("b")])
        playlist.repeatMode = .all
        XCTAssertEqual(playlist.afterEndOfFile().title, "b")
        XCTAssertEqual(playlist.afterEndOfFile().title, "a")
    }

    func testOpenCheckRejectsEmptyAndText() {
        XCTAssertEqual(MediaOpenCheck.problem(byteCount: 0, header: Data()), "That file is empty.")
        let text = Data("this is a note, not a movie.".utf8)
        XCTAssertEqual(
            MediaOpenCheck.problem(byteCount: text.count, header: text),
            "That file looks like text, not video or audio."
        )
        var header = Data([0x00, 0x00, 0x00, 0x18])
        header.append(Data("ftypmp42".utf8))
        XCTAssertNil(MediaOpenCheck.problem(byteCount: 4096, header: header))
        XCTAssertNil(MediaOpenCheck.problem(byteCount: 100, header: Data()))
    }

    func testCacheClampAndOldSettings() throws {
        XCTAssertEqual(PlayerSettings.clampedCache(8), 64)
        XCTAssertEqual(PlayerSettings.clampedCache(9000), 2048)
        XCTAssertEqual(PlayerSettings(cacheMegabytes: 80).cacheBackMegabytes, 80)
        XCTAssertEqual(PlayerSettings(cacheMegabytes: 2000).cacheBackMegabytes, 128)
        let settings = try JSONDecoder().decode(PlayerSettings.self, from: Data(#"{"cacheMegabytes":128}"#.utf8))
        XCTAssertTrue(settings.quitWhenWindowCloses)
        XCTAssertFalse(settings.resizeToVideoOnOpen)
        XCTAssertEqual(settings.cacheMegabytes, 128)
        XCTAssertEqual(settings.cacheBackMegabytes, 128)
        let huge = try JSONDecoder().decode(PlayerSettings.self, from: Data(#"{"cacheMegabytes":9000}"#.utf8))
        XCTAssertEqual(huge.cacheMegabytes, 2048)
    }
}

private extension Playlist.EndAction {
    var title: String? {
        if case .play(let item) = self { return item.title }
        return nil
    }
}
