import XCTest
@testable import MeowxCore

final class ChapterTests: XCTestCase {
    private let chapters = [
        MediaChapter(index: 0, title: "Cold open", time: 0),
        MediaChapter(index: 1, title: "", time: 10),
        MediaChapter(index: 2, title: "Credits", time: 25)
    ]

    func testChapterIndexFollowsThePlayhead() {
        XCTAssertEqual(ChapterNav.index(at: 0, chapters: chapters), 0)
        XCTAssertEqual(ChapterNav.index(at: 9.8, chapters: chapters), 0)
        XCTAssertEqual(ChapterNav.index(at: 10, chapters: chapters), 1)
        XCTAssertEqual(ChapterNav.index(at: 24, chapters: chapters), 1)
        XCTAssertEqual(ChapterNav.index(at: 25.1, chapters: chapters), 2)
        XCTAssertEqual(ChapterNav.index(at: .nan, chapters: chapters), -1)
        XCTAssertEqual(ChapterNav.index(at: 5, chapters: []), -1)
    }

    func testChapterNeighborStopsAtTheEnds() {
        XCTAssertEqual(ChapterNav.neighbor(current: -1, count: 3, direction: 1), 0)
        XCTAssertNil(ChapterNav.neighbor(current: -1, count: 3, direction: -1))
        XCTAssertNil(ChapterNav.neighbor(current: 0, count: 3, direction: -1))
        XCTAssertEqual(ChapterNav.neighbor(current: 1, count: 3, direction: 1), 2)
        XCTAssertNil(ChapterNav.neighbor(current: 2, count: 3, direction: 1))
        XCTAssertNil(ChapterNav.neighbor(current: 0, count: 0, direction: 1))
        XCTAssertNil(ChapterNav.neighbor(current: 0, count: 3, direction: 0))
    }

    func testChapterTicksSkipTheEnds() {
        XCTAssertEqual(ChapterNav.tickFractions(times: [0, 25, 50, 99.8], duration: 100), [0.25, 0.5])
        XCTAssertEqual(ChapterNav.tickFractions(times: [10], duration: 0), [])
        XCTAssertEqual(ChapterNav.displayTitle(index: 1, title: "  "), "Chapter 2")
        XCTAssertEqual(ChapterNav.status(index: 1, title: "Middle", count: 4), "Middle (2/4)")
    }

    func testFlipCropAndPictureMath() {
        XCTAssertEqual(VideoFlip.filter(horizontal: false, vertical: false), "")
        XCTAssertEqual(VideoFlip.filter(horizontal: true, vertical: false), "hflip")
        XCTAssertEqual(VideoFlip.filter(horizontal: false, vertical: true), "vflip")
        XCTAssertEqual(VideoFlip.filter(horizontal: true, vertical: true), "hflip,vflip")

        XCTAssertEqual(CropPreset.next(""), "16:9")
        XCTAssertEqual(CropPreset.next("1:1"), "")
        XCTAssertEqual(CropPreset.next("nope"), "16:9")
        XCTAssertEqual(CropPreset.rectangle(videoWidth: 1920, videoHeight: 1080, preset: "4:3"), "1440x1080")
        XCTAssertEqual(CropPreset.rectangle(videoWidth: 1920, videoHeight: 1080, preset: "2.35:1"), "1920x816")
        XCTAssertEqual(CropPreset.rectangle(videoWidth: 1920, videoHeight: 1080, preset: "1:1"), "1080x1080")
        XCTAssertNil(CropPreset.rectangle(videoWidth: 1920, videoHeight: 1080, preset: "16:9"))
        XCTAssertNil(CropPreset.rectangle(videoWidth: 0, videoHeight: 1080, preset: "4:3"))
        XCTAssertEqual(CropPreset.label(""), "Crop: none")

        XCTAssertEqual(PictureLevels.clamped(140), 100)
        XCTAssertEqual(PictureLevels.clamped(-140), -100)
        XCTAssertEqual(PictureLevels.clamped(.nan), 0)
        XCTAssertTrue(PictureLevels.neutral.isNeutral)
        let blown = PictureLevels(brightness: 400, contrast: -3, saturation: 0, gamma: 0, hue: 0).clamped()
        XCTAssertEqual(blown.brightness, 100)
        XCTAssertFalse(blown.isNeutral)
    }
}
