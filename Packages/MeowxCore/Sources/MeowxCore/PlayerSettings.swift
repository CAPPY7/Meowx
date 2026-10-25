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
        openSubtitlesAPIKey: String = ""
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
    }

    public static let `default` = PlayerSettings()

    public var resolvedScreenshotFolder: URL {
        if !screenshotFolder.isEmpty {
            return URL(fileURLWithPath: (screenshotFolder as NSString).expandingTildeInPath, isDirectory: true)
        }
        let pictures = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        return pictures.appendingPathComponent("Meowx", isDirectory: true)
    }
}
