import Foundation

public enum ScreenshotFormat: String, Codable, CaseIterable, Sendable {
    case png
    case jpg
}

public struct PlayerSettings: Codable, Equatable, Sendable {
    public var hardwareDecoding: Bool
    public var subtitleLanguage: String
    public var audioLanguage: String
    public var cacheMegabytes: Int
    public var screenshotFolder: String
    public var screenshotFormat: ScreenshotFormat
    public var subtitleFont: String
    public var subtitleSize: Double
    public var subtitleColorHex: String
    public var subtitlePosition: Double
    public var openSubtitlesAPIKey: String
    public var hideChromeWhilePlaying: Bool
    public var chromeHideDelay: Double
    public var clickToPause: Bool
    public var scrollAdjustsVolume: Bool
    public var scrollSeeks: Bool
    public var quitWhenWindowCloses: Bool
    public var resizeToVideoOnOpen: Bool
    public var playlistOpen: Bool
    public var doubleClickSidesSeek: Bool
    public var showRemainingTime: Bool

    public init(
        hardwareDecoding: Bool = true,
        subtitleLanguage: String = "",
        audioLanguage: String = "",
        cacheMegabytes: Int = 512,
        screenshotFolder: String = "",
        screenshotFormat: ScreenshotFormat = .png,
        subtitleFont: String = "",
        subtitleSize: Double = 55,
        subtitleColorHex: String = "#FFFFFF",
        subtitlePosition: Double = 100,
        openSubtitlesAPIKey: String = "",
        hideChromeWhilePlaying: Bool = true,
        chromeHideDelay: Double = 3,
        clickToPause: Bool = true,
        scrollAdjustsVolume: Bool = true,
        scrollSeeks: Bool = true,
        quitWhenWindowCloses: Bool = true,
        resizeToVideoOnOpen: Bool = false,
        playlistOpen: Bool = true,
        doubleClickSidesSeek: Bool = true,
        showRemainingTime: Bool = false
    ) {
        self.hardwareDecoding = hardwareDecoding
        self.subtitleLanguage = subtitleLanguage
        self.audioLanguage = audioLanguage
        self.cacheMegabytes = Self.clampedCache(cacheMegabytes)
        self.screenshotFolder = screenshotFolder
        self.screenshotFormat = screenshotFormat
        self.subtitleFont = subtitleFont
        self.subtitleSize = subtitleSize
        self.subtitleColorHex = subtitleColorHex
        self.subtitlePosition = subtitlePosition
        self.openSubtitlesAPIKey = openSubtitlesAPIKey
        self.hideChromeWhilePlaying = hideChromeWhilePlaying
        self.chromeHideDelay = Self.clampedHideDelay(chromeHideDelay)
        self.clickToPause = clickToPause
        self.scrollAdjustsVolume = scrollAdjustsVolume
        self.scrollSeeks = scrollSeeks
        self.quitWhenWindowCloses = quitWhenWindowCloses
        self.resizeToVideoOnOpen = resizeToVideoOnOpen
        self.playlistOpen = playlistOpen
        self.doubleClickSidesSeek = doubleClickSidesSeek
        self.showRemainingTime = showRemainingTime
    }

    public static let `default` = PlayerSettings()

    public static func clampedHideDelay(_ value: Double) -> Double {
        guard value.isFinite else { return 3 }
        return min(10, max(1, value))
    }

    public static func clampedCache(_ value: Int) -> Int {
        min(2048, max(64, value))
    }

    /// Backward cache stays small so a large forward cache cannot double memory use.
    public var cacheBackMegabytes: Int { min(cacheMegabytes, 128) }

    public var resolvedScreenshotFolder: URL {
        if !screenshotFolder.isEmpty {
            return URL(fileURLWithPath: (screenshotFolder as NSString).expandingTildeInPath, isDirectory: true)
        }
        let pictures = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        return pictures.appendingPathComponent("Meowx", isDirectory: true)
    }

    private enum CodingKeys: String, CodingKey {
        case hardwareDecoding
        case subtitleLanguage
        case audioLanguage
        case cacheMegabytes
        case screenshotFolder
        case screenshotFormat
        case subtitleFont
        case subtitleSize
        case subtitleColorHex
        case subtitlePosition
        case openSubtitlesAPIKey
        case hideChromeWhilePlaying
        case chromeHideDelay
        case clickToPause
        case scrollAdjustsVolume
        case scrollSeeks
        case quitWhenWindowCloses
        case resizeToVideoOnOpen
        case playlistOpen
        case doubleClickSidesSeek
        case showRemainingTime
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            hardwareDecoding: try container.decodeIfPresent(Bool.self, forKey: .hardwareDecoding) ?? true,
            subtitleLanguage: try container.decodeIfPresent(String.self, forKey: .subtitleLanguage) ?? "",
            audioLanguage: try container.decodeIfPresent(String.self, forKey: .audioLanguage) ?? "",
            cacheMegabytes: try container.decodeIfPresent(Int.self, forKey: .cacheMegabytes) ?? 512,
            screenshotFolder: try container.decodeIfPresent(String.self, forKey: .screenshotFolder) ?? "",
            screenshotFormat: try container.decodeIfPresent(ScreenshotFormat.self, forKey: .screenshotFormat) ?? .png,
            subtitleFont: try container.decodeIfPresent(String.self, forKey: .subtitleFont) ?? "",
            subtitleSize: try container.decodeIfPresent(Double.self, forKey: .subtitleSize) ?? 55,
            subtitleColorHex: try container.decodeIfPresent(String.self, forKey: .subtitleColorHex) ?? "#FFFFFF",
            subtitlePosition: try container.decodeIfPresent(Double.self, forKey: .subtitlePosition) ?? 100,
            openSubtitlesAPIKey: try container.decodeIfPresent(String.self, forKey: .openSubtitlesAPIKey) ?? "",
            hideChromeWhilePlaying: try container.decodeIfPresent(Bool.self, forKey: .hideChromeWhilePlaying) ?? true,
            chromeHideDelay: try container.decodeIfPresent(Double.self, forKey: .chromeHideDelay) ?? 3,
            clickToPause: try container.decodeIfPresent(Bool.self, forKey: .clickToPause) ?? true,
            scrollAdjustsVolume: try container.decodeIfPresent(Bool.self, forKey: .scrollAdjustsVolume) ?? true,
            scrollSeeks: try container.decodeIfPresent(Bool.self, forKey: .scrollSeeks) ?? true,
            quitWhenWindowCloses: try container.decodeIfPresent(Bool.self, forKey: .quitWhenWindowCloses) ?? true,
            resizeToVideoOnOpen: try container.decodeIfPresent(Bool.self, forKey: .resizeToVideoOnOpen) ?? false,
            playlistOpen: try container.decodeIfPresent(Bool.self, forKey: .playlistOpen) ?? true,
            doubleClickSidesSeek: try container.decodeIfPresent(Bool.self, forKey: .doubleClickSidesSeek) ?? true,
            showRemainingTime: try container.decodeIfPresent(Bool.self, forKey: .showRemainingTime) ?? false
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(hardwareDecoding, forKey: .hardwareDecoding)
        try container.encode(subtitleLanguage, forKey: .subtitleLanguage)
        try container.encode(audioLanguage, forKey: .audioLanguage)
        try container.encode(cacheMegabytes, forKey: .cacheMegabytes)
        try container.encode(screenshotFolder, forKey: .screenshotFolder)
        try container.encode(screenshotFormat, forKey: .screenshotFormat)
        try container.encode(subtitleFont, forKey: .subtitleFont)
        try container.encode(subtitleSize, forKey: .subtitleSize)
        try container.encode(subtitleColorHex, forKey: .subtitleColorHex)
        try container.encode(subtitlePosition, forKey: .subtitlePosition)
        try container.encode(openSubtitlesAPIKey, forKey: .openSubtitlesAPIKey)
        try container.encode(hideChromeWhilePlaying, forKey: .hideChromeWhilePlaying)
        try container.encode(chromeHideDelay, forKey: .chromeHideDelay)
        try container.encode(clickToPause, forKey: .clickToPause)
        try container.encode(scrollAdjustsVolume, forKey: .scrollAdjustsVolume)
        try container.encode(scrollSeeks, forKey: .scrollSeeks)
        try container.encode(quitWhenWindowCloses, forKey: .quitWhenWindowCloses)
        try container.encode(resizeToVideoOnOpen, forKey: .resizeToVideoOnOpen)
        try container.encode(playlistOpen, forKey: .playlistOpen)
        try container.encode(doubleClickSidesSeek, forKey: .doubleClickSidesSeek)
        try container.encode(showRemainingTime, forKey: .showRemainingTime)
    }
}
