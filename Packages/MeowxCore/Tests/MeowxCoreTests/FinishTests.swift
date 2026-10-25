import XCTest
@testable import MeowxCore

final class FinishTests: XCTestCase {
    func testEqualizerPresetsAndFlatIsSilent() {
        XCTAssertEqual(EqualizerPreset.flat.gains, Array(repeating: 0, count: 10))
        XCTAssertEqual(EqualizerPreset.bass.gains.count, 10)
        XCTAssertNil(AudioChain.equalizer(EqualizerPreset.flat.gains))
        let chain = AudioChain.equalizer(EqualizerPreset.bass.gains) ?? ""
        XCTAssertTrue(chain.hasPrefix("lavfi=[equalizer=f=31.25"))
        XCTAssertTrue(chain.contains("g=6.0"))
        XCTAssertEqual(PlayerSettings.tenBands([20, -20]).count, 10)
        XCTAssertEqual(PlayerSettings.tenBands([20, -20])[0], 12, accuracy: 0.001)
        XCTAssertEqual(PlayerSettings.tenBands([20, -20])[1], -12, accuracy: 0.001)
    }

    func testVersionCompareAndReleaseTag() {
        XCTAssertTrue(VersionCompare.isNewer("v1.0.9", than: "1.0.8"))
        XCTAssertFalse(VersionCompare.isNewer("1.0.8", than: "v1.0.8"))
        XCTAssertFalse(VersionCompare.isNewer("1.2", than: "1.2.0"))
        XCTAssertTrue(VersionCompare.isNewer("1.10.0", than: "1.9.9"))
        XCTAssertFalse(VersionCompare.isNewer("not-a-version", than: "1.0.0"))
        let data = Data(#"{"tag_name":"v1.2.0"}"#.utf8)
        XCTAssertEqual(ReleaseTag.parse(data), "v1.2.0")
        XCTAssertNil(ReleaseTag.parse(Data("[]".utf8)))
    }

    func testLogsDropPathsUnlessAsked() {
        XCTAssertEqual(LogPrivacy.redact("open /Films/a.mkv now", includePaths: false), "open [path] now")
        XCTAssertEqual(LogPrivacy.redact("open /Films/a.mkv now", includePaths: true), "open /Films/a.mkv now")
        XCTAssertFalse(LogPrivacy.redact("saved ~/Library/Meowx/a.log", includePaths: false).contains("Library"))
    }

    func testSleepAndStop() {
        let start = Date(timeIntervalSince1970: 1_000)
        XCTAssertFalse(SleepPlan.fires(started: start, minutes: 0, now: start.addingTimeInterval(10_000)))
        XCTAssertFalse(SleepPlan.fires(started: start, minutes: 15, now: start.addingTimeInterval(899)))
        XCTAssertTrue(SleepPlan.fires(started: start, minutes: 15, now: start.addingTimeInterval(900)))
        XCTAssertFalse(SleepPlan.fires(started: nil, minutes: 15, now: start))
        XCTAssertTrue(PlaybackStop.endsHere(request: .file, hasNextFile: true))
        XCTAssertFalse(PlaybackStop.endsHere(request: .playlist, hasNextFile: true))
        XCTAssertTrue(PlaybackStop.endsHere(request: .playlist, hasNextFile: false))
        XCTAssertFalse(PlaybackStop.endsHere(request: .none, hasNextFile: false))
    }

    func testTrackMemoryRoundTripAndMediaInfo() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = TrackMemoryStore(directory: directory)
        store.save(TrackMemory(audioID: 2, subtitleID: 0, subtitleDelay: 0.4, zoom: 0.5), for: "file:/a.mkv#1")
        let again = TrackMemoryStore(directory: directory)
        XCTAssertEqual(again.recall("file:/a.mkv#1")?.audioID, 2)
        XCTAssertEqual(again.recall("file:/a.mkv#1")?.zoom ?? 0, 0.5, accuracy: 0.001)
        let text = MediaFacts(
            container: "mkv",
            path: "/tmp/a.mkv",
            byteCount: 2_000_000,
            video: "1920x1080 h264",
            audio: "aac",
            subtitles: "eng",
            bitrate: "2.00 Mb/s",
            hdr: "no",
            hardware: "videotoolbox"
        ).text()
        XCTAssertTrue(text.contains("Container: mkv"))
        XCTAssertTrue(text.contains("Size: 2.0 MB"))
        XCTAssertTrue(text.contains("Hardware decoding: videotoolbox"))
    }

    func testNewShortcutsDoNotStealStats() {
        XCTAssertEqual(ShortcutMap.match(ShortcutInput(token: "minus"), overrides: [:])?.id, "subtitleSmaller")
        XCTAssertEqual(ShortcutMap.match(ShortcutInput(token: "equal"), overrides: [:])?.id, "subtitleLarger")
        XCTAssertEqual(ShortcutMap.match(ShortcutInput(token: "minus", command: true), overrides: [:])?.id, "zoomOut")
        XCTAssertEqual(ShortcutMap.match(ShortcutInput(token: "equal", command: true), overrides: [:])?.id, "zoomIn")
        XCTAssertEqual(ShortcutMap.match(ShortcutInput(token: "i"), overrides: [:])?.id, "stats")
        XCTAssertEqual(ShortcutMap.match(ShortcutInput(token: "i", command: true), overrides: [:])?.id, "mediaInfo")
    }
}
