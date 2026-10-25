import Foundation

public enum AppAppearance: String, Codable, CaseIterable, Sendable {
    case dark
    case system
}

public enum SpeedStep: String, Codable, CaseIterable, Sendable {
    case ladder
    case tenth
    case quarter

    public static let ladderValues: [Double] = [0.25, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 2.5, 3, 4]

    public func nudged(_ current: Double, direction: Int) -> Double {
        guard direction != 0 else { return current }
        switch self {
        case .ladder:
            if direction > 0 { return Self.ladderValues.first { $0 > current + 0.01 } ?? 4 }
            return Self.ladderValues.last { $0 < current - 0.01 } ?? 0.25
        case .tenth:
            return min(4, max(0.25, current + 0.1 * Double(direction)))
        case .quarter:
            return min(4, max(0.25, current + 0.25 * Double(direction)))
        }
    }
}

public enum ToneMap: String, Codable, CaseIterable, Sendable {
    case auto
    case clip
    case linear
    case hable
    case bt2390 = "bt.2390"

    public var label: String {
        switch self {
        case .auto: return "Auto"
        case .clip: return "Clip"
        case .linear: return "Linear"
        case .hable: return "Hable"
        case .bt2390: return "BT.2390"
        }
    }
}

public struct KeyBinding: Codable, Equatable, Sendable {
    public var token: String
    public var command: Bool
    public var shift: Bool
    public var option: Bool
    public var control: Bool

    public init(token: String, command: Bool = false, shift: Bool = false, option: Bool = false, control: Bool = false) {
        self.token = token
        self.command = command
        self.shift = shift
        self.option = option
        self.control = control
    }

    public init(_ input: ShortcutInput) {
        token = input.token
        command = input.command
        shift = input.shift
        option = input.option
        control = input.control
    }
}

public enum EndChoice {
    /// Repeat-one still replays the current file. Play-next is what starts a different file.
    public static func shouldAdvance(playNext: Bool, repeatMode: RepeatMode) -> Bool {
        playNext || repeatMode == .one
    }
}

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
    public var appearance: AppAppearance
    public var resumeOnOpen: Bool
    public var playNext: Bool
    public var endBehavior: RepeatMode
    public var speedStep: SpeedStep
    public var seekShort: Double
    public var seekMedium: Double
    public var seekLong: Double
    public var toneMapping: ToneMap
    public var defaultAspect: String
    public var deinterlaceOnOpen: Bool
    public var screenshotWithSubtitles: Bool
    public var audioDevice: String
    public var loudnessNormalize: Bool
    public var audioCompressor: Bool
    public var rememberVolume: Bool
    public var savedVolume: Double
    public var subtitleOutline: Double
    public var subtitleDelayDefault: Double
    public var subtitleEncoding: String
    public var verboseLog: Bool
    public var shortcutOverrides: [String: KeyBinding]
    public var equalizer: [Double]
    public var checkForUpdates: Bool
    public var includePathsInLogs: Bool
    public var sleepMinutes: Int

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
        playlistOpen: Bool = false,
        doubleClickSidesSeek: Bool = true,
        showRemainingTime: Bool = false,
        appearance: AppAppearance = .dark,
        resumeOnOpen: Bool = true,
        playNext: Bool = true,
        endBehavior: RepeatMode = .off,
        speedStep: SpeedStep = .ladder,
        seekShort: Double = 5,
        seekMedium: Double = 10,
        seekLong: Double = 30,
        toneMapping: ToneMap = .auto,
        defaultAspect: String = "",
        deinterlaceOnOpen: Bool = false,
        screenshotWithSubtitles: Bool = true,
        audioDevice: String = "auto",
        loudnessNormalize: Bool = false,
        audioCompressor: Bool = false,
        rememberVolume: Bool = true,
        savedVolume: Double = 100,
        subtitleOutline: Double = 1,
        subtitleDelayDefault: Double = 0,
        subtitleEncoding: String = "auto",
        verboseLog: Bool = false,
        shortcutOverrides: [String: KeyBinding] = [:],
        equalizer: [Double] = [],
        checkForUpdates: Bool = true,
        includePathsInLogs: Bool = false,
        sleepMinutes: Int = 0
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
        self.appearance = appearance
        self.resumeOnOpen = resumeOnOpen
        self.playNext = playNext
        self.endBehavior = endBehavior
        self.speedStep = speedStep
        self.seekShort = Self.clampedSeek(seekShort)
        self.seekMedium = Self.clampedSeek(seekMedium)
        self.seekLong = Self.clampedSeek(seekLong)
        self.toneMapping = toneMapping
        self.defaultAspect = defaultAspect
        self.deinterlaceOnOpen = deinterlaceOnOpen
        self.screenshotWithSubtitles = screenshotWithSubtitles
        self.audioDevice = audioDevice.isEmpty ? "auto" : audioDevice
        self.loudnessNormalize = loudnessNormalize
        self.audioCompressor = audioCompressor
        self.rememberVolume = rememberVolume
        self.savedVolume = min(200, max(0, savedVolume))
        self.subtitleOutline = Self.clampedOutline(subtitleOutline)
        self.subtitleDelayDefault = subtitleDelayDefault
        self.subtitleEncoding = subtitleEncoding.isEmpty ? "auto" : subtitleEncoding
        self.verboseLog = verboseLog
        self.shortcutOverrides = shortcutOverrides
        self.equalizer = Self.tenBands(equalizer)
        self.checkForUpdates = checkForUpdates
        self.includePathsInLogs = includePathsInLogs
        self.sleepMinutes = [0, 15, 30, 45, 60, 90].contains(sleepMinutes) ? sleepMinutes : 0
    }

    public static func tenBands(_ values: [Double]) -> [Double] {
        var next = values.prefix(10).map { value -> Double in
            guard value.isFinite else { return 0 }
            return min(12, max(-12, value))
        }
        while next.count < 10 { next.append(0) }
        return Array(next)
    }

    public static let `default` = PlayerSettings()

    public static func clampedHideDelay(_ value: Double) -> Double {
        guard value.isFinite else { return 3 }
        return min(10, max(1, value))
    }

    public static func clampedCache(_ value: Int) -> Int {
        min(2048, max(64, value))
    }

    public static func clampedSeek(_ value: Double) -> Double {
        guard value.isFinite else { return 5 }
        return min(120, max(1, value))
    }

    public static func clampedOutline(_ value: Double) -> Double {
        guard value.isFinite else { return 1 }
        return min(8, max(0, value))
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
        case playlistOpen = "playlistCardOpen"
        case doubleClickSidesSeek
        case showRemainingTime
        case appearance
        case resumeOnOpen
        case playNext
        case endBehavior
        case speedStep
        case seekShort
        case seekMedium
        case seekLong
        case toneMapping
        case defaultAspect
        case deinterlaceOnOpen
        case screenshotWithSubtitles
        case audioDevice
        case loudnessNormalize
        case audioCompressor
        case rememberVolume
        case savedVolume
        case subtitleOutline
        case subtitleDelayDefault
        case subtitleEncoding
        case verboseLog
        case shortcutOverrides
        case equalizer
        case checkForUpdates
        case includePathsInLogs
        case sleepMinutes
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
            playlistOpen: try container.decodeIfPresent(Bool.self, forKey: .playlistOpen) ?? false,
            doubleClickSidesSeek: try container.decodeIfPresent(Bool.self, forKey: .doubleClickSidesSeek) ?? true,
            showRemainingTime: try container.decodeIfPresent(Bool.self, forKey: .showRemainingTime) ?? false,
            appearance: try container.decodeIfPresent(AppAppearance.self, forKey: .appearance) ?? .dark,
            resumeOnOpen: try container.decodeIfPresent(Bool.self, forKey: .resumeOnOpen) ?? true,
            playNext: try container.decodeIfPresent(Bool.self, forKey: .playNext) ?? true,
            endBehavior: try container.decodeIfPresent(RepeatMode.self, forKey: .endBehavior) ?? .off,
            speedStep: try container.decodeIfPresent(SpeedStep.self, forKey: .speedStep) ?? .ladder,
            seekShort: try container.decodeIfPresent(Double.self, forKey: .seekShort) ?? 5,
            seekMedium: try container.decodeIfPresent(Double.self, forKey: .seekMedium) ?? 10,
            seekLong: try container.decodeIfPresent(Double.self, forKey: .seekLong) ?? 30,
            toneMapping: try container.decodeIfPresent(ToneMap.self, forKey: .toneMapping) ?? .auto,
            defaultAspect: try container.decodeIfPresent(String.self, forKey: .defaultAspect) ?? "",
            deinterlaceOnOpen: try container.decodeIfPresent(Bool.self, forKey: .deinterlaceOnOpen) ?? false,
            screenshotWithSubtitles: try container.decodeIfPresent(Bool.self, forKey: .screenshotWithSubtitles) ?? true,
            audioDevice: try container.decodeIfPresent(String.self, forKey: .audioDevice) ?? "auto",
            loudnessNormalize: try container.decodeIfPresent(Bool.self, forKey: .loudnessNormalize) ?? false,
            audioCompressor: try container.decodeIfPresent(Bool.self, forKey: .audioCompressor) ?? false,
            rememberVolume: try container.decodeIfPresent(Bool.self, forKey: .rememberVolume) ?? true,
            savedVolume: try container.decodeIfPresent(Double.self, forKey: .savedVolume) ?? 100,
            subtitleOutline: try container.decodeIfPresent(Double.self, forKey: .subtitleOutline) ?? 1,
            subtitleDelayDefault: try container.decodeIfPresent(Double.self, forKey: .subtitleDelayDefault) ?? 0,
            subtitleEncoding: try container.decodeIfPresent(String.self, forKey: .subtitleEncoding) ?? "auto",
            verboseLog: try container.decodeIfPresent(Bool.self, forKey: .verboseLog) ?? false,
            shortcutOverrides: try container.decodeIfPresent([String: KeyBinding].self, forKey: .shortcutOverrides) ?? [:],
            equalizer: try container.decodeIfPresent([Double].self, forKey: .equalizer) ?? [],
            checkForUpdates: try container.decodeIfPresent(Bool.self, forKey: .checkForUpdates) ?? true,
            includePathsInLogs: try container.decodeIfPresent(Bool.self, forKey: .includePathsInLogs) ?? false,
            sleepMinutes: try container.decodeIfPresent(Int.self, forKey: .sleepMinutes) ?? 0
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
        try container.encode(appearance, forKey: .appearance)
        try container.encode(resumeOnOpen, forKey: .resumeOnOpen)
        try container.encode(playNext, forKey: .playNext)
        try container.encode(endBehavior, forKey: .endBehavior)
        try container.encode(speedStep, forKey: .speedStep)
        try container.encode(seekShort, forKey: .seekShort)
        try container.encode(seekMedium, forKey: .seekMedium)
        try container.encode(seekLong, forKey: .seekLong)
        try container.encode(toneMapping, forKey: .toneMapping)
        try container.encode(defaultAspect, forKey: .defaultAspect)
        try container.encode(deinterlaceOnOpen, forKey: .deinterlaceOnOpen)
        try container.encode(screenshotWithSubtitles, forKey: .screenshotWithSubtitles)
        try container.encode(audioDevice, forKey: .audioDevice)
        try container.encode(loudnessNormalize, forKey: .loudnessNormalize)
        try container.encode(audioCompressor, forKey: .audioCompressor)
        try container.encode(rememberVolume, forKey: .rememberVolume)
        try container.encode(savedVolume, forKey: .savedVolume)
        try container.encode(subtitleOutline, forKey: .subtitleOutline)
        try container.encode(subtitleDelayDefault, forKey: .subtitleDelayDefault)
        try container.encode(subtitleEncoding, forKey: .subtitleEncoding)
        try container.encode(verboseLog, forKey: .verboseLog)
        try container.encode(shortcutOverrides, forKey: .shortcutOverrides)
        try container.encode(equalizer, forKey: .equalizer)
        try container.encode(checkForUpdates, forKey: .checkForUpdates)
        try container.encode(includePathsInLogs, forKey: .includePathsInLogs)
        try container.encode(sleepMinutes, forKey: .sleepMinutes)
    }
}
