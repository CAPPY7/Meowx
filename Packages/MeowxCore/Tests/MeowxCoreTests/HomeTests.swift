import XCTest
@testable import MeowxCore

final class HomeTests: XCTestCase {
    func testPasteLinkAcceptsLinksAndPathsOnly() {
        XCTAssertEqual(PasteLink.url(from: "  https://example.com/a.mkv ")?.absoluteString, "https://example.com/a.mkv")
        XCTAssertEqual(PasteLink.url(from: "/tmp/clip.mp4")?.path, "/tmp/clip.mp4")
        XCTAssertEqual(PasteLink.url(from: "file:///tmp/clip.mp4")?.path, "/tmp/clip.mp4")
        XCTAssertNil(PasteLink.url(from: "hello"))
        XCTAssertNil(PasteLink.url(from: ""))
        XCTAssertNil(PasteLink.url(from: "https://example.com\nsecond"))
    }

    func testLyricsParseAndFollowThePlayhead() {
        let lines = LyricsFile.parse("[00:01.00]Hello\n[00:05.50]There\nnope\n[01:00]Later\n")
        XCTAssertEqual(lines.map(\.text), ["Hello", "There", "Later"])
        XCTAssertEqual(lines.map(\.time), [1, 5.5, 60])
        XCTAssertNil(LyricsFile.current(at: 0, lines: lines))
        XCTAssertEqual(LyricsFile.current(at: 2, lines: lines), "Hello")
        XCTAssertEqual(LyricsFile.current(at: 5.5, lines: lines), "There")
        XCTAssertTrue(LyricsFile.parse("just words").isEmpty)
    }

    func testResumeCardsKeepTheNewest() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ResumeStore(directory: directory)
        let older = Date(timeIntervalSince1970: 10)
        let newer = Date(timeIntervalSince1970: 20)
        store.remember(position: 12, duration: 100, for: "file:/films/old.mkv#4", now: older)
        store.remember(position: 40, duration: 80, for: "file:/films/new.mkv#8", now: newer)
        let cards = store.latest(limit: 1)
        XCTAssertEqual(cards.map(\.title), ["new.mkv"])
        XCTAssertEqual(cards.first?.url?.path, "/films/new.mkv")
        XCTAssertEqual(cards.first?.remaining ?? 0, 40, accuracy: 0.001)
        XCTAssertEqual(ResumeStore.url(for: "file:/tmp/a.mp4#12")?.path, "/tmp/a.mp4")
        XCTAssertNil(ResumeStore.url(for: "file:#1"))
    }
}
