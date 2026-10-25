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
        chromeHideDelay: Double = 3
    ) {
        self.hardwareDecoding = hardwareDecoding
        self.subtitleLanguage = subtitleLanguage
        self.audioLanguage = audioLanguage
        self.cacheMegabytes = min(4096, max(32, cacheMegabytes))
        self.screenshotFolder = screenshotFolder
        self.screenshotFormat = screenshotFormat
        self.subtitleFont = subtitleFont
        self.subtitleSize = subtitleSize
        self.subtitleColorHex = subtitleColorHex
        self.subtitlePosition = subtitlePosition
        self.openSubtitlesAPIKey = openSubtitlesAPIKey
        self.hideChromeWhilePlaying = hideChromeWhilePlaying
        self.chromeHideDelay = Self.clampedHideDelay(chromeHideDelay)
    }

    public static let `default` = PlayerSettings()

    public static func clampedHideDelay(_ value: Double) -> Double {
        guard value.isFinite else { return 3 }
        return min(10, max(1, value))
    }

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
            chromeHideDelay: try container.decodeIfPresent(Double.self, forKey: .chromeHideDelay) ?? 3
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
    }
}
