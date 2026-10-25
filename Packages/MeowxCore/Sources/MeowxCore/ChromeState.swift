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
