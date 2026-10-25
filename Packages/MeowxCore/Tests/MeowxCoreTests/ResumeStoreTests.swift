import XCTest
@testable import MeowxCore

final class ResumeStoreTests: XCTestCase {
    private func makeStore() throws -> (ResumeStore, URL) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        return (ResumeStore(directory: directory), directory)
    }

    func testRemembersMiddleAndForgetsEdges() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        store.remember(position: 12, duration: 100, for: "movie")
        XCTAssertEqual(store.position(for: "movie") ?? 0, 12, accuracy: 0.001)
        store.remember(position: 1, duration: 100, for: "movie")
        XCTAssertNil(store.position(for: "movie"))
        store.remember(position: 95, duration: 100, for: "credits")
        XCTAssertNil(store.position(for: "credits"))
        store.remember(position: 40, duration: 0, for: "live")
        XCTAssertNil(store.position(for: "live"))
    }

    func testPersistsAcrossInstances() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = ResumeStore(directory: directory)
        first.remember(position: 48, duration: 200, for: "a")
        first.remember(position: 10, duration: 50, for: "b")
        let second = ResumeStore(directory: directory)
        XCTAssertEqual(second.position(for: "a") ?? 0, 48, accuracy: 0.001)
        XCTAssertEqual(second.position(for: "b") ?? 0, 10, accuracy: 0.001)
        XCTAssertNil(second.position(for: "missing"))
    }

    func testFileKeysIncludeSize() {
        let url = URL(fileURLWithPath: "/tmp/meowx-test.mp4")
        let key = ResumeStore.key(for: url)
        XCTAssertTrue(key.hasPrefix("file:/tmp/meowx-test.mp4#"))
        let remote = ResumeStore.key(for: URL(string: "https://example.com/a.mkv")!)
        XCTAssertEqual(remote, "https://example.com/a.mkv")
    }
}
