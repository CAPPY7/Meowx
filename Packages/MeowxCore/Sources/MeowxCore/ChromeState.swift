import Foundation

/// Pure rule for whether playback chrome should be on screen.
/// AppKit applies the result. This type does not touch windows.
public struct ChromeState: Equatable, Sendable {
    public var autoHideEnabled: Bool
    public var paused: Bool
    public var mediaLoaded: Bool
    public var hasVideo: Bool
    public var scrubbing: Bool
    public var pointerOverControls: Bool
    public var overlayOpen: Bool
    public var secondsSinceActivity: Double
    public var hideAfter: Double
    public var showingError: Bool

    public init(
        autoHideEnabled: Bool,
        paused: Bool,
        mediaLoaded: Bool,
        hasVideo: Bool,
        scrubbing: Bool,
        pointerOverControls: Bool,
        overlayOpen: Bool,
        secondsSinceActivity: Double,
        hideAfter: Double,
        showingError: Bool
    ) {
        self.autoHideEnabled = autoHideEnabled
        self.paused = paused
        self.mediaLoaded = mediaLoaded
        self.hasVideo = hasVideo
        self.scrubbing = scrubbing
        self.pointerOverControls = pointerOverControls
        self.overlayOpen = overlayOpen
        self.secondsSinceActivity = secondsSinceActivity
        self.hideAfter = hideAfter
        self.showingError = showingError
    }

    /// True while anything other than the picture should stay visible.
    /// A resting pointer, including one sitting on the bar, does not keep it up.
    public var visible: Bool {
        if !autoHideEnabled { return true }
        if paused || !mediaLoaded || !hasVideo { return true }
        if scrubbing || overlayOpen || showingError { return true }
        if secondsSinceActivity < hideAfter { return true }
        return false
    }
}

/// Volume and seek should show a readout only. Every other shortcut may reveal the bar.
public enum ChromeWake {
    public static func revealsBar(shortcutID: String) -> Bool {
        switch shortcutID {
        case "seekBack", "seekForward", "seekBack30", "seekForward30", "seekStart", "seekEnd",
             "volumeUp", "volumeDown", "volumeUp10", "volumeDown10", "mute":
            return false
        default:
            return true
        }
    }
}

public struct NetworkTools: Equatable, Sendable {
    public var ytdlp: String?
    public var ffmpeg: String?
    public var helperDirectory: String?

    public init(ytdlp: String?, ffmpeg: String?, helperDirectory: String?) {
        self.ytdlp = ytdlp
        self.ffmpeg = ffmpeg
        self.helperDirectory = helperDirectory
    }

    /// Prefer the copies inside the app. Fall back to whatever is already on the Mac.
    public static func resolve(helperDirectory: String?, systemYtDlp: String?, systemFfmpeg: String?) -> NetworkTools {
        let bundledYt = executable(in: helperDirectory, name: "yt-dlp")
        let bundledFf = executable(in: helperDirectory, name: "ffmpeg")
        let directory = (bundledYt != nil || bundledFf != nil) ? helperDirectory : nil
        return NetworkTools(
            ytdlp: bundledYt ?? blankToNil(systemYtDlp),
            ffmpeg: bundledFf ?? blankToNil(systemFfmpeg),
            helperDirectory: directory
        )
    }

    private static func blankToNil(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func executable(in directory: String?, name: String) -> String? {
        guard let directory, !directory.isEmpty else { return nil }
        let path = (directory as NSString).appendingPathComponent(name)
        return FileManager.default.isExecutableFile(atPath: path) ? path : nil
    }
}
