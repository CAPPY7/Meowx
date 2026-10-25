import AppKit
import AVFoundation
import MeowxCore
import Observation
import os
import UniformTypeIdentifiers

@Observable
final class PlayerModel {
    static let shared = PlayerModel()
    static let speedSteps: [Double] = [0.25, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 2.5, 3, 4]

    let videoView = MPVVideoView()
    private(set) var engine: MPVController?
    private let resume = ResumeStore(directory: AppPaths.support)
    private var started = false
    private var resumeOnLoad = false
    private var timer: Timer?
    private var tickCount = 0
    private var thumbTask: Task<Void, Never>?
    private var gate = Date.distantPast

    private var recentAction: [String: Date] = [:]

    private func allow(_ key: String) -> Bool {
        let now = Date()
        if let last = recentAction[key], now.timeIntervalSince(last) < 0.03 { return false }
        recentAction[key] = now
        return true
    }

    private func passGate() -> Bool {
        let now = Date()
        if now.timeIntervalSince(gate) < 0.05 { return false }
        gate = now
        return true
    }

    private var statusToken = UUID()
    private var glyphToken = UUID()
    private var pendingTrackAnnouncement: String?
    private var lastPoke = Date()
    private var lastHideSchedule = Date.distantPast
    private var hideWork: DispatchWorkItem?
    private let uiLog = Logger(subsystem: "com.cappy7.meowx", category: "ui")
    private var activity: NSObjectProtocol?
    private var pipPanel: NSPanel?
    private weak var mainHost: NSView?
    private weak var contentWindow: NSWindow?
    private let pipDelegate = PiPCloseDelegate()
    private(set) var ytdlpPath: String?
    private var endGate = EndOfFileGate()
    private var fitOnLoad = false
    private var loggedChapterCount = -1
    private var cropFrame = (0, 0)
    var recentRevision = 0

    var playlist = Playlist()
    var settings = PlayerSettings.default
    var paused = true
    var position = 0.0
    var duration = 0.0
    var volume = 100.0
    var muted = false
    var speed = 1.0
    var buffering = false
    var opening = false
    var showsVideo = true
    var artist = ""
    var album = ""
    var lyrics: [LyricLine] = []
    var lyricPlain = ""
    var mediaTitle = ""
    var artwork: NSImage?
    var tracks: [MediaTrack] = []
    var audioTrackID = 0
    var subtitleTrackID = 0
    var subDelay = 0.0
    var audioDelay = 0.0
    var loopA: Double?
    var loopB: Double?
    var rotation = 0
    var aspectOverride = ""
    var subtitlesHidden = false
    var fileLoop = false
    var chapters: [MediaChapter] = []
    var chapterIndex = -1
    var flipHorizontal = false
    var flipVertical = false
    var cropPreset = ""
    var deinterlace = false
    var picture = PictureLevels.neutral
    var pictureOpen = false
    var hwdec = ""
    var videoWidth = 0
    var videoHeight = 0
    var fps = 0.0
    var droppedFrames = 0
    var videoCodec = ""
    var audioCodec = ""
    var videoBitrate = 0.0
    var cacheSeconds = 0.0
    var videoGamma = ""
    var videoPrimaries = ""
    var statsVisible = false
    var chromeShown = true
    var controlsHovered = false
    var topHovered = false
    var playlistHovered = false
    var trafficInset: CGFloat = 0
    var menuOpen = false
    var playlistShown = true
    var fullscreen = false
    var pictureInPicture = false
    var alwaysOnTop = false
    var scrubbing = false
    var scrub = 0.0
    var thumbImage: NSImage?
    var thumbTime: Double?
    var showThumb = false
    var dropTargeted = false
    var urlPrompt = false
    var timePrompt = false
    var shortcutPrompt = false
    var searchOpen = false
    var errorMessage: String?
    var errorTitle = "Can't play this"
    var errorURL: URL?
    var errorItemID: UUID?
    var statusText: String?
    var statusProgress: Double?
    var statusMark: StatusMark = .generic
    var actionGlyph: ActionGlyph?
    var transportOpen = false
    var engineError: String?

    var displayTitle: String {
        if !mediaTitle.isEmpty { return mediaTitle }
        return playlist.current?.title ?? "Meowx"
    }

    var mediaDetail: String {
        MediaLine.detail(width: videoWidth, height: videoHeight, codec: videoCodec)
    }

    var showsHDR: Bool {
        HDRBadge.isHDR(gamma: videoGamma, primaries: videoPrimaries)
    }

    func togglePlaylist() {
        setPlaylistOpen(!playlistShown)
    }

    func setPlaylistOpen(_ open: Bool) {
        guard playlistShown != open else { return }
        playlistShown = open
        if !open { playlistHovered = false }
        updateSettings { $0.playlistOpen = open }
        poke()
    }

    func noteTrafficInset(buttonMaxX: CGFloat, fullscreen: Bool) {
        let next = CGFloat(TrafficClearance.inset(buttonMaxX: Double(buttonMaxX), fullscreen: fullscreen))
        if abs(trafficInset - next) > 0.5 { trafficInset = next }
    }

    func resumeFraction(for item: PlaylistItem) -> Double {
        if item.id == playlist.current?.id, duration > 0 {
            return min(1, max(0, position / duration))
        }
        return resume.fraction(for: ResumeStore.key(for: item.url)) ?? 0
    }

    func rowDuration(_ item: PlaylistItem) -> Double? {
        if item.id == playlist.current?.id, duration > 0 { return duration }
        return resume.duration(for: ResumeStore.key(for: item.url))
    }

    var subtitleTracks: [MediaTrack] { tracks.filter { $0.kind == "sub" } }
    var audioTracks: [MediaTrack] { tracks.filter { $0.kind == "audio" } }

    private init() {
        settings = SettingsStore.load()
        playlistShown = settings.playlistOpen
    }

    func start() {
        guard !started else { return }
        started = true
        ytdlpPath = Self.which("yt-dlp")
        if let engine = MPVController(settings: settings, ytdlpPath: ytdlpPath) {
            engine.delegate = self
            engine.videoView = videoView
            videoView.controller = engine
            engine.installWakeup()
            self.engine = engine
        } else {
            engineError = "The playback engine didn't start. Install libmpv with brew install mpv and rebuild."
        }
        videoView.markFramePending()
        NowPlayingService.shared.install()
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged(_:)), name: NSWindow.didEnterFullScreenNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged(_:)), name: NSWindow.didExitFullScreenNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(menuBegan(_:)), name: NSMenu.didBeginTrackingNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(menuEnded(_:)), name: NSMenu.didEndTrackingNotification, object: nil)
        evaluateChrome(reason: "start")
    }

    func prepareToQuit() {
        saveResume()
        timer?.invalidate()
        ThumbnailService.shared.shutdown()
        engine?.shutdown()
        engine = nil
        if let activity {
            ProcessInfo.processInfo.endActivity(activity)
        }
    }

    func attachContentWindow(_ window: NSWindow) {
        contentWindow = window
        if window.frameAutosaveName.isEmpty {
            window.setFrameAutosaveName("MeowxMain")
        }
        window.minSize = NSSize(width: 780, height: 480)
    }

    func presentWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let contentWindow {
            contentWindow.makeKeyAndOrderFront(nil)
            return
        }
        if let window = NSApp.windows.first(where: { $0.canBecomeMain && !$0.isSheet }) {
            contentWindow = window
            window.makeKeyAndOrderFront(nil)
        }
    }

    /// True lets the window close (and the app quit, when that setting is on). False hides it and pauses.
    func allowWindowClose() -> Bool {
        saveResume()
        if settings.quitWhenWindowCloses {
            uiLog.info("window close will quit")
            return true
        }
        pause()
        let window = contentWindow
        DispatchQueue.main.async { window?.orderOut(nil) }
        uiLog.info("window hidden, playback paused")
        return false
    }

    func attachMainHost(_ host: NSView) {
        mainHost = host
        guard !pictureInPicture else { return }
        if videoView.superview !== host {
            videoView.removeFromSuperview()
            host.addSubview(videoView)
        }
        videoView.frame = host.bounds
        videoView.autoresizingMask = [.width, .height]
    }

    func add(urls: [URL], playNow: Bool) {
        presentWindow()
        var media: [PlaylistItem] = []
        var subtitles: [URL] = []
        for url in urls {
            let expanded = expand(url)
            for item in expanded {
                if MediaFiles.isSubtitle(item.url) {
                    subtitles.append(item.url)
                } else if !MediaFiles.isJunk(item.url) {
                    if let problem = rejected(item.url) {
                        reportProblem(problem, title: "Can't play this", url: item.url)
                        continue
                    }
                    media.append(item)
                }
            }
        }
        if let subtitle = subtitles.first, playlist.current != nil {
            engine?.addSubtitle(path: subtitle.isFileURL ? subtitle.path : subtitle.absoluteString)
            showStatus("Subtitle added")
        }
        guard !media.isEmpty else { return }
        playlist.append(media)
        if playNow, let first = media.first {
            playlist.select(id: first.id)
            loadCurrent(resume: true)
        } else if engine != nil, paused, position == 0, playlist.current?.id == media.first?.id {
            loadCurrent(resume: true)
        }
    }

    func openFiles(playNow: Bool) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsOtherFileTypes = true
        panel.prompt = playNow ? "Open" : "Add"
        guard panel.runModal() == .OK else { return }
        add(urls: panel.urls, playNow: playNow)
    }

    func openSubtitleFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = []
        panel.allowsOtherFileTypes = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        engine?.addSubtitle(path: url.path)
        showStatus("Subtitle added")
    }

    func openURL(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let url: URL
        if let parsed = URL(string: trimmed), parsed.scheme != nil {
            url = parsed
        } else if trimmed.hasPrefix("/") || trimmed.hasPrefix("~") {
            url = URL(fileURLWithPath: (trimmed as NSString).expandingTildeInPath)
        } else if FileManager.default.fileExists(atPath: trimmed) {
            url = URL(fileURLWithPath: trimmed)
        } else if let https = URL(string: "https://\(trimmed)") {
            url = https
        } else {
            return
        }
        add(urls: [url], playNow: true)
        urlPrompt = false
    }

    func pasteLink() {
        let text = NSPasteboard.general.string(forType: .string) ?? ""
        guard let url = PasteLink.url(from: text) else {
            reportProblem("The clipboard doesn't have a link or a file path.", title: "No link")
            return
        }
        add(urls: [url], playNow: true)
    }

    func continueWatching() -> [ResumeStore.Card] {
        resume.latest(limit: 6)
    }

    func reportProblem(_ message: String, title: String = "Can't play this", url: URL? = nil, itemID: UUID? = nil) {
        errorMessage = message
        errorTitle = title
        errorURL = url
        errorItemID = itemID
        evaluateChrome(reason: "error")
    }

    func dismissProblem() {
        errorMessage = nil
        errorURL = nil
        errorItemID = nil
    }

    func play(id: UUID) {
        playlist.select(id: id)
        loadCurrent(resume: true)
    }

    func remove(id: UUID) {
        let removingCurrent = playlist.current?.id == id
        playlist.remove(id: id)
        if playlist.items.isEmpty {
            clearTransport()
            return
        }
        if removingCurrent { loadCurrent(resume: true) }
    }

    func move(from offsets: IndexSet, to offset: Int) {
        playlist.move(fromOffsets: offsets, toOffset: offset)
    }

    func toggleShuffle() {
        playlist.setShuffle(!playlist.shuffleEnabled)
        flashStatus(playlist.shuffleEnabled ? "Shuffle on" : "Shuffle off")
    }

    func cycleRepeat() {
        switch playlist.repeatMode {
        case .off: playlist.repeatMode = .all
        case .all: playlist.repeatMode = .one
        case .one: playlist.repeatMode = .off
        }
        let name: String
        switch playlist.repeatMode {
        case .off: name = "off"
        case .all: name = "all"
        case .one: name = "one"
        }
        flashStatus("Repeat: \(name)")
    }

    func savePlaylist() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = []
        panel.nameFieldStringValue = "Playlist.m3u"
        panel.allowsOtherFileTypes = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? playlist.m3uText().write(to: url, atomically: true, encoding: .utf8)
    }

    func revealCurrent() {
        guard let url = playlist.current?.url, url.isFileURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func makeDefaultPlayer() {
        let application = Bundle.main.bundleURL
        let types: [UTType] = [.movie, .video, .audio, .mpeg4Movie, .quickTimeMovie]
        var failures: [String] = []
        for type in types {
            do {
                try NSWorkspace.shared.setDefaultApplication(at: application, toOpen: type)
            } catch {
                failures.append("\(type.identifier): \(error.localizedDescription)")
            }
        }
        if failures.isEmpty {
            showStatus("Meowx is the default player for video and audio")
        } else {
            errorMessage = "macOS did not accept Meowx as the default player. \(failures.joined(separator: " "))"
            errorTitle = "Not the default player"
            errorURL = nil
            errorItemID = nil
        }
    }

    func togglePause() {
        guard passGate() else { return }
        if playlist.current == nil {
            openFiles(playNow: true)
            return
        }
        if paused {
            play()
            flashGlyph(.play)
        } else {
            pause()
            flashGlyph(.pause)
        }
    }

    func play() {
        guard playlist.current != nil else { return }
        paused = false
        engine?.setPaused(false)
        poke()
        updateActivity()
        videoView.updateTouchBar()
    }

    func pause() {
        paused = true
        engine?.setPaused(true)
        evaluateChrome(reason: "pause")
        saveResume()
        updateActivity()
        videoView.updateTouchBar()
        NowPlayingService.shared.update(model: self)
    }

    func next() {
        guard allow("skip") else { return }
        guard let item = playlist.skipped(by: 1) else { return }
        flashGlyph(.skipForward)
        load(item, resume: true)
    }

    func previous() {
        guard allow("skip") else { return }
        if position > 3 {
            seek(to: 0, exact: true)
            flashGlyph(.seekBack)
            flashStatus("Start", mark: .seekBack)
            return
        }
        guard let item = playlist.skipped(by: -1) else {
            seek(to: 0, exact: true)
            flashGlyph(.seekBack)
            return
        }
        flashGlyph(.skipBack)
        load(item, resume: true)
    }

    func seek(by delta: Double) {
        guard allow("seek") else { return }
        engine?.seekRelative(delta)
        position = max(0, position + delta)
        let whole = Int(delta.rounded())
        let forward = delta >= 0
        flashGlyph(forward ? .seekForward : .seekBack)
        flashStatus(whole >= 0 ? "Seek +\(whole) s" : "Seek \(whole) s", mark: forward ? .seekForward : .seekBack)
    }

    func seek(to seconds: Double, exact: Bool) {
        let target = max(0, seconds)
        position = target
        engine?.seekAbsolute(target, exact: exact)
        poke()
    }

    func scrubTo(_ value: Double) {
        scrubbing = true
        scrub = value
        engine?.seekAbsolute(value, exact: false)
        requestThumb(at: value)
        poke()
    }

    func endScrub() {
        seek(to: scrub, exact: true)
        scrubbing = false
        showThumb = false
    }

    func hover(at time: Double) {
        requestThumb(at: time)
    }

    func endHover() {
        if !scrubbing { showThumb = false }
    }

    func setVolume(_ value: Double) {
        volume = min(200, max(0, value))
        engine?.setVolume(volume)
        if volume > 0 && muted {
            muted = false
            engine?.setMuted(false)
        }
    }

    func nudgeVolume(_ delta: Double) {
        guard allow("volume") else { return }
        setVolume(volume + delta)
        flashVolume()
    }

    func toggleMute() {
        guard passGate() else { return }
        muted.toggle()
        engine?.setMuted(muted)
        flashVolume()
    }

    func setSpeed(_ value: Double) {
        speed = min(4, max(0.25, value))
        engine?.setSpeed(speed)
        flashStatus(speed == 1 ? "Speed 1x" : String(format: "Speed %.2gx", speed), mark: .speed)
    }

    func nudgeSpeed(_ direction: Int) {
        guard allow("speed") else { return }
        if direction > 0 {
            setSpeed(Self.speedSteps.first { $0 > speed + 0.01 } ?? 4)
        } else {
            setSpeed(Self.speedSteps.last { $0 < speed - 0.01 } ?? 0.25)
        }
    }

    func resetSpeed() { setSpeed(1) }

    func frameStep(backward: Bool) {
        guard allow("frame") else { return }
        engine?.frameStep(backward: backward)
        paused = true
        evaluateChrome(reason: "pause")
    }

    func cycleSubtitles() {
        guard passGate() else { return }
        pendingTrackAnnouncement = "sub"
        engine?.cycle("sub")
        DispatchQueue.main.async { [weak self] in
            self?.refreshTracks()
            self?.announceTracksIfNeeded()
        }
    }

    func cycleAudio() {
        guard passGate() else { return }
        pendingTrackAnnouncement = "audio"
        engine?.cycle("audio")
        DispatchQueue.main.async { [weak self] in
            self?.refreshTracks()
            self?.announceTracksIfNeeded()
        }
    }

    func previousSubtitle() {
        guard passGate() else { return }
        pendingTrackAnnouncement = "sub"
        engine?.cycle("sub", backward: true)
        DispatchQueue.main.async { [weak self] in
            self?.refreshTracks()
            self?.announceTracksIfNeeded()
        }
    }

    func previousAudio() {
        guard passGate() else { return }
        pendingTrackAnnouncement = "audio"
        engine?.cycle("audio", backward: true)
        DispatchQueue.main.async { [weak self] in
            self?.refreshTracks()
            self?.announceTracksIfNeeded()
        }
    }

    func seekToStart() {
        guard allow("seek") else { return }
        seek(to: 0, exact: true)
        flashStatus("Start")
    }

    func seekToEnd() {
        guard allow("seek") else { return }
        guard duration > 0 else {
            flashStatus("No duration yet")
            return
        }
        seek(to: max(0, duration - 0.05), exact: true)
        flashStatus("End")
    }

    func jumpToPercent(_ digit: Int) {
        guard allow("seek") else { return }
        guard let seconds = PlaybackJump.seconds(digit: digit, duration: duration) else {
            flashStatus("No duration yet")
            return
        }
        seek(to: seconds, exact: true)
        flashStatus("\(digit * 10)%")
    }

    func selectSubtitle(_ id: Int) {
        subtitleTrackID = id
        engine?.selectTrack("sid", id: id)
        let name = id <= 0 ? "Subtitles off" : (subtitleTracks.first { $0.id == id }?.label ?? "Subtitle \(id)")
        flashStatus(name)
    }

    func selectAudio(_ id: Int) {
        audioTrackID = id
        engine?.selectTrack("aid", id: id)
        let name = audioTracks.first { $0.id == id }?.label ?? "Audio \(id)"
        flashStatus(name)
    }

    func nudgeSubDelay(_ delta: Double) {
        subDelay = engine?.nudge("sub-delay", by: delta) ?? (subDelay + delta)
        flashStatus(String(format: "Subtitle delay %+.1f s", subDelay))
    }

    func nudgeAudioDelay(_ delta: Double) {
        audioDelay = engine?.nudge("audio-delay", by: delta) ?? (audioDelay + delta)
        flashStatus(String(format: "Audio delay %+.1f s", audioDelay))
    }

    func nudgeSubtitleSize(_ delta: Double) {
        updateSettings { $0.subtitleSize = min(96, max(18, $0.subtitleSize + delta)) }
        flashStatus("Subtitle size \(Int(settings.subtitleSize.rounded()))")
    }

    func applyPointerScroll(deltaX: Double, deltaY: Double, precise: Bool, momentum: Bool) {
        let action = ScrollAction.interpret(
            deltaX: deltaX,
            deltaY: deltaY,
            precise: precise,
            momentum: momentum,
            volumeEnabled: settings.scrollAdjustsVolume,
            seekEnabled: settings.scrollSeeks
        )
        if action.volumeDelta != 0 {
            setVolume(volume + action.volumeDelta)
            flashVolume()
        }
        if action.seekDelta != 0 {
            engine?.seekRelative(action.seekDelta)
            position = max(0, position + action.seekDelta)
            let whole = Int(action.seekDelta.rounded())
            flashStatus(whole >= 0 ? "Seek +\(whole) s" : "Seek \(whole) s", mark: action.seekDelta >= 0 ? .seekForward : .seekBack)
        }
        if action.volumeDelta != 0 || action.seekDelta != 0 { poke() }
    }

    func jumpToTime(_ text: String) {
        guard let seconds = TimeJump.seconds(from: text) else {
            flashStatus("Could not read that time")
            return
        }
        seek(to: seconds, exact: true)
        timePrompt = false
        flashStatus("Jumped to \(TimeFormat.string(seconds))")
    }

    func copyCurrentLocation() {
        guard let url = playlist.current?.url else { return }
        let text = url.isFileURL ? url.path : url.absoluteString
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        flashStatus("Copied")
    }

    func flashStatus(_ text: String, progress: Double? = nil, mark: StatusMark = .generic) {
        showStatus(text, progress: progress, mark: mark)
        poke()
    }

    func flashGlyph(_ glyph: ActionGlyph) {
        actionGlyph = glyph
        let token = UUID()
        glyphToken = token
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            guard let self, self.glyphToken == token else { return }
            self.actionGlyph = nil
        }
    }

    func toggleTimeReadout() {
        updateSettings { $0.showRemainingTime.toggle() }
    }

    func flashVolume() {
        let level = muted ? 0 : min(1, max(0, volume / 200))
        flashStatus(muted ? "Muted" : "Volume \(Int(volume.rounded()))%", progress: level, mark: .volume)
    }

    func performShortcut(_ id: String) {
        switch id {
        case "playPause": togglePause()
        case "previous": previous()
        case "next": next()
        case "seekBack": seek(by: -5)
        case "seekForward": seek(by: 5)
        case "seekBack30": seek(by: -30)
        case "seekForward30": seek(by: 30)
        case "volumeUp": nudgeVolume(5)
        case "volumeDown": nudgeVolume(-5)
        case "volumeUp10": nudgeVolume(10)
        case "volumeDown10": nudgeVolume(-10)
        case "mute": toggleMute()
        case "cycleAudio": cycleAudio()
        case "previousAudio": previousAudio()
        case "audioDelayEarlier": nudgeAudioDelay(-0.1)
        case "audioDelayLater": nudgeAudioDelay(0.1)
        case "cycleSubtitles": cycleSubtitles()
        case "previousSubtitle": previousSubtitle()
        case "toggleSubtitleVisibility": toggleSubtitleVisibility()
        case "subDelayEarlier": nudgeSubDelay(-0.1)
        case "subDelayLater": nudgeSubDelay(0.1)
        case "speedDown": nudgeSpeed(-1)
        case "speedUp": nudgeSpeed(1)
        case "speedReset": resetSpeed()
        case "frameBack": frameStep(backward: true)
        case "frameForward": frameStep(backward: false)
        case "jump": timePrompt = true
        case "loopCycle": cycleLoopPoint()
        case "loopFile": toggleFileLoop()
        case "screenshot": screenshot()
        case "rotate": rotateClockwise()
        case "cycleAspect": cycleAspect()
        case "flipHorizontal": toggleFlipHorizontal()
        case "flipVertical": toggleFlipVertical()
        case "cycleCrop": cycleCrop()
        case "deinterlace": toggleDeinterlace()
        case "resetZoom": resetZoomAndPan()
        case "picture": togglePicturePanel()
        case "fullScreen", "fullScreenSystem", "leaveFullScreen": toggleFullscreen()
        case "pictureInPicture": togglePictureInPicture()
        case "alwaysOnTop": toggleAlwaysOnTop()
        case "windowHalf": resizeWindow(scale: 0.5)
        case "windowActual": resizeWindow(scale: 1)
        case "windowDouble": resizeWindow(scale: 2)
        case "windowFit": fitWindowToScreen()
        case "stats": toggleStats()
        case "open": openFiles(playNow: true)
        case "openURL": urlPrompt = true
        case "pasteLink": pasteLink()
        case "shortcuts": shortcutPrompt = true
        case "addToPlaylist": openFiles(playNow: false)
        case "showPlaylist": togglePlaylist()
        case "seekStart": seekToStart()
        case "seekEnd": seekToEnd()
        case "previousChapter": stepChapter(-1)
        case "nextChapter": stepChapter(1)
        default:
            if id.hasPrefix("jump"), let digit = Int(id.dropFirst(4)), (0...9).contains(digit) {
                jumpToPercent(digit)
            }
        }
        poke()
    }

    func setLoopA() {
        loopA = position
        engine?.setString("ab-loop-a", String(format: "%.3f", position))
        flashStatus("Loop A set", mark: .loop)
    }

    func setLoopB() {
        loopB = position
        engine?.setString("ab-loop-b", String(format: "%.3f", position))
        flashStatus("Loop B set", mark: .loop)
    }

    func clearLoop() {
        loopA = nil
        loopB = nil
        engine?.setString("ab-loop-a", "no")
        engine?.setString("ab-loop-b", "no")
        flashStatus("A-B loop cleared", mark: .loop)
    }

    func cycleLoopPoint() {
        switch LoopCycle.next(hasA: loopA != nil, hasB: loopB != nil) {
        case .setA: setLoopA()
        case .setB: setLoopB()
        case .clear: clearLoop()
        }
    }

    func toggleFileLoop() {
        fileLoop.toggle()
        applyVideoAdjustments()
        flashStatus(fileLoop ? "Loop file on" : "Loop file off", mark: .loop)
    }

    func toggleSubtitleVisibility() {
        subtitlesHidden.toggle()
        applyVideoAdjustments()
        flashStatus(subtitlesHidden ? "Subtitles hidden" : "Subtitles shown")
    }

    func rotateClockwise() {
        guard allow("video") else { return }
        rotation = RotationCycle.next(degrees: rotation)
        applyVideoAdjustments()
        flashStatus("Rotate \(rotation)°")
    }

    func cycleAspect() {
        guard allow("video") else { return }
        aspectOverride = AspectCycle.next(current: aspectOverride)
        applyVideoAdjustments()
        flashStatus(AspectCycle.label(aspectOverride))
    }

    func setAspect(_ preset: String) {
        guard allow("video") else { return }
        aspectOverride = AspectCycle.presets.contains(preset) ? preset : ""
        applyVideoAdjustments()
        flashStatus(AspectCycle.label(aspectOverride))
    }

    func seekChapter(_ index: Int) {
        guard allow("chapter") else { return }
        goToChapter(index)
    }

    func stepChapter(_ direction: Int) {
        guard allow("chapter") else { return }
        guard let next = ChapterNav.neighbor(current: chapterIndex, count: chapters.count, direction: direction) else {
            flashStatus(chapters.isEmpty ? "No chapters" : (direction > 0 ? "Last chapter" : "First chapter"))
            return
        }
        goToChapter(next)
    }

    func toggleFlipHorizontal() {
        guard allow("video") else { return }
        flipHorizontal.toggle()
        applyVideoAdjustments()
        flashStatus(flipHorizontal ? "Flip horizontal on" : "Flip horizontal off")
    }

    func toggleFlipVertical() {
        guard allow("video") else { return }
        flipVertical.toggle()
        applyVideoAdjustments()
        flashStatus(flipVertical ? "Flip vertical on" : "Flip vertical off")
    }

    func setCrop(_ preset: String) {
        guard allow("video") else { return }
        applyCrop(preset)
    }

    func cycleCrop() {
        guard allow("video") else { return }
        applyCrop(CropPreset.next(cropPreset))
    }

    func toggleDeinterlace() {
        guard allow("video") else { return }
        deinterlace.toggle()
        applyVideoAdjustments()
        flashStatus(deinterlace ? "Deinterlace on" : "Deinterlace off")
    }

    func resetZoomAndPan() {
        guard allow("video") else { return }
        engine?.setDouble("video-zoom", 0)
        engine?.setDouble("video-pan-x", 0)
        engine?.setDouble("video-pan-y", 0)
        flashStatus("Zoom and pan reset")
    }

    func togglePicturePanel() {
        pictureOpen.toggle()
        if pictureOpen { flashStatus("Picture") }
        evaluateChrome(reason: "picture")
        poke()
    }

    func closePicturePanel() {
        guard pictureOpen else { return }
        pictureOpen = false
        evaluateChrome(reason: "picture")
    }

    func updatePicture(_ body: (inout PictureLevels) -> Void) {
        var copy = picture
        body(&copy)
        picture = copy.clamped()
        applyPicture()
        poke()
    }

    func resetPicture() {
        picture = .neutral
        applyPicture()
        flashStatus("Picture reset")
    }

    private func goToChapter(_ index: Int) {
        guard chapters.indices.contains(index) else {
            flashStatus("No chapters")
            return
        }
        let chapter = chapters[index]
        seek(to: chapter.time, exact: true)
        chapterIndex = index
        flashStatus(ChapterNav.status(index: index, title: chapter.title, count: chapters.count))
    }

    private func applyCrop(_ preset: String) {
        cropPreset = CropPreset.order.contains(preset) ? preset : ""
        applyVideoAdjustments()
        flashStatus(CropPreset.label(cropPreset))
    }

    func resizeWindow(scale: Double) {
        let percent = Int((scale * 100).rounded())
        applyFrame(WindowFit.scaled(
            videoWidth: videoWidth,
            videoHeight: videoHeight,
            scale: scale,
            maxWidth: screenLimit().width,
            maxHeight: screenLimit().height
        ), label: "Window \(percent)%")
    }

    func fitWindowToScreen() {
        let limit = screenLimit()
        applyFrame(WindowFit.fitted(
            videoWidth: videoWidth,
            videoHeight: videoHeight,
            maxWidth: limit.width,
            maxHeight: limit.height
        ), label: "Fit to screen")
    }

    private func applyFrame(_ size: FrameSize?, label: String) {
        guard let size else {
            flashStatus("No video size yet")
            return
        }
        guard let window = playbackWindow else {
            flashStatus("No window")
            return
        }
        if window.styleMask.contains(.fullScreen) {
            flashStatus("Leave full screen first")
            return
        }
        let width = max(160, size.width)
        let height = max(90, size.height)
        let content = NSRect(x: 0, y: 0, width: width, height: height)
        var frame = window.frameRect(forContentRect: content)
        let current = window.frame
        frame.origin.x = current.midX - frame.width / 2
        frame.origin.y = current.midY - frame.height / 2
        if let screen = window.screen?.visibleFrame {
            if frame.maxX > screen.maxX { frame.origin.x = screen.maxX - frame.width }
            if frame.minX < screen.minX { frame.origin.x = screen.minX }
            if frame.maxY > screen.maxY { frame.origin.y = screen.maxY - frame.height }
            if frame.minY < screen.minY { frame.origin.y = screen.minY }
        }
        window.setFrame(frame, display: true, animate: true)
        flashStatus(label)
    }

    private func screenLimit() -> (width: Double, height: Double) {
        let frame = playbackWindow?.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        return (max(320, Double(frame.width) - 32), max(180, Double(frame.height) - 48))
    }

    private var playbackWindow: NSWindow? {
        if let contentWindow { return contentWindow }
        if let main = NSApp.mainWindow, main.canBecomeMain { return main }
        return NSApp.windows.first { $0.canBecomeMain && !$0.isSheet }
    }

    private func syncFloatingAspect() {
        guard pictureInPicture, let pipPanel, videoWidth > 0, videoHeight > 0 else { return }
        let size = NSSize(width: videoWidth, height: videoHeight)
        if pipPanel.contentAspectRatio != size {
            pipPanel.contentAspectRatio = size
        }
    }

    private func rejected(_ url: URL) -> String? {
        guard url.isFileURL, !MediaFiles.isM3U(url) else { return nil }
        let count = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? -1
        if count == 0 { return MediaOpenCheck.problem(byteCount: 0, header: Data()) }
        guard count > 0, let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        let header = (try? handle.read(upToCount: 64)) ?? Data()
        return MediaOpenCheck.problem(byteCount: count, header: header)
    }

    private func applyVideoAdjustments() {
        engine?.setString("video-rotate", String(rotation))
        engine?.setString("video-aspect-override", AspectCycle.mpvValue(aspectOverride))
        engine?.setString("sub-visibility", subtitlesHidden ? "no" : "yes")
        engine?.setString("loop-file", fileLoop ? "inf" : "no")
        engine?.setVideoFilter(VideoFlip.filter(horizontal: flipHorizontal, vertical: flipVertical))
        let crop = CropPreset.rectangle(videoWidth: videoWidth, videoHeight: videoHeight, preset: cropPreset)
        engine?.setString("video-crop", crop ?? "")
        engine?.setString("deinterlace", deinterlace ? "yes" : "no")
        applyPicture()
    }

    private func applyPicture() {
        engine?.setDouble("brightness", picture.brightness)
        engine?.setDouble("contrast", picture.contrast)
        engine?.setDouble("saturation", picture.saturation)
        engine?.setDouble("gamma", picture.gamma)
        engine?.setDouble("hue", picture.hue)
    }

    func toggleStats() {
        guard passGate() else { return }
        statsVisible.toggle()
    }

    func toggleFullscreen() {
        guard passGate() else { return }
        playbackWindow?.toggleFullScreen(nil)
    }

    func toggleAlwaysOnTop() {
        alwaysOnTop.toggle()
        playbackWindow?.level = alwaysOnTop ? .floating : .normal
    }

    func togglePictureInPicture() {
        guard passGate() else { return }
        if pictureInPicture {
            pipPanel?.close()
        } else {
            enterPictureInPicture()
        }
    }

    func finishPictureInPicture() {
        pictureInPicture = false
        pipPanel = nil
        if let mainHost { attachMainHost(mainHost) }
        uiLog.info("floating window closed, video returned")
    }

    func screenshot() {
        let folder = settings.resolvedScreenshotFolder
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let url = folder.appendingPathComponent("Meowx-\(stamp).\(settings.screenshotFormat.rawValue)")
        let saved = engine?.screenshot(to: url, format: settings.screenshotFormat.rawValue) == true
        if saved {
            flashStatus("Saved \(url.lastPathComponent)")
        } else {
            errorMessage = "Couldn't save the screenshot."
            errorTitle = "Couldn't save the screenshot"
            errorURL = nil
            errorItemID = nil
        }
    }

    func updateSettings(_ body: (inout PlayerSettings) -> Void) {
        var copy = settings
        body(&copy)
        copy.cacheMegabytes = PlayerSettings.clampedCache(copy.cacheMegabytes)
        copy.chromeHideDelay = PlayerSettings.clampedHideDelay(copy.chromeHideDelay)
        settings = copy
        SettingsStore.save(copy)
        engine?.apply(copy)
        evaluateChrome(reason: "settings")
    }

    func resetSettings() {
        settings = .default
        playlistShown = settings.playlistOpen
        SettingsStore.save(settings)
        engine?.apply(settings)
        evaluateChrome(reason: "settings")
    }

    func poke() {
        lastPoke = Date()
        if !chromeShown {
            uiLog.info("activity revealed chrome")
        }
        applyChrome(true, reason: "activity")
        let now = Date()
        if hideWork != nil, now.timeIntervalSince(lastHideSchedule) < 0.1 { return }
        lastHideSchedule = now
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.evaluateChrome(reason: "timer")
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + settings.chromeHideDelay, execute: work)
    }

    func evaluateChrome(reason: String) {
        let state = ChromeState(
            autoHideEnabled: settings.hideChromeWhilePlaying,
            paused: paused,
            mediaLoaded: playlist.current != nil,
            hasVideo: showsVideo,
            scrubbing: scrubbing,
            pointerOverControls: controlsHovered || topHovered,
            overlayOpen: urlPrompt || timePrompt || shortcutPrompt || searchOpen || menuOpen || pictureOpen || transportOpen,
            secondsSinceActivity: Date().timeIntervalSince(lastPoke),
            hideAfter: settings.chromeHideDelay,
            showingError: errorMessage != nil || engineError != nil
        )
        applyChrome(state.visible, reason: reason)
    }

    private func applyChrome(_ shown: Bool, reason: String) {
        if !shown {
            controlsHovered = false
            topHovered = false
        }
        guard chromeShown != shown else { return }
        chromeShown = shown
        uiLog.info("chrome \(shown ? "show" : "hide", privacy: .public) reason \(reason, privacy: .public)")
        if !shown {
            NSCursor.setHiddenUntilMouseMoves(true)
        }
    }

    func searchSubtitles(language: String) async throws -> [SubtitleHit] {
        let query = playlist.current?.title ?? ""
        return try await SubtitleSearch.search(apiKey: settings.openSubtitlesAPIKey, query: query, language: language)
    }

    func useSubtitle(_ hit: SubtitleHit) async throws {
        let file = try await SubtitleSearch.download(apiKey: settings.openSubtitlesAPIKey, fileID: hit.fileID)
        engine?.addSubtitle(path: file.path)
        showStatus("Subtitle added")
        searchOpen = false
    }

    private func loadCurrent(resume: Bool) {
        guard let current = playlist.current else { return }
        load(current, resume: resume)
    }

    private func load(_ item: PlaylistItem, resume: Bool) {
        resumeOnLoad = resume
        opening = true
        buffering = false
        artwork = nil
        artist = ""
        album = ""
        lyrics = []
        lyricPlain = ""
        mediaTitle = ""
        dismissProblem()
        tracks = []
        loopA = nil
        loopB = nil
        subDelay = 0
        audioDelay = 0
        position = 0
        chapters = []
        chapterIndex = -1
        loggedChapterCount = -1
        cropFrame = (0, 0)
        if item.url.isFileURL {
            NSDocumentController.shared.noteNewRecentDocumentURL(item.url)
            recentRevision += 1
        }
        engine?.load(item.url)
        play()
    }

    private func tick() {
        guard let engine, playlist.current != nil else { return }
        let snap = engine.snapshot()
        if !scrubbing { position = snap.position }
        if snap.duration > 0 { duration = snap.duration }
        volume = snap.volume
        muted = snap.muted
        speed = snap.speed
        hwdec = snap.hwdec
        videoWidth = snap.width
        videoHeight = snap.height
        fps = snap.fps
        droppedFrames = snap.droppedFrames
        videoCodec = snap.videoCodec
        audioCodec = snap.audioCodec
        videoBitrate = snap.videoBitrate
        videoGamma = snap.gamma
        videoPrimaries = snap.primaries
        cacheSeconds = snap.cacheSeconds
        if videoWidth > 0, videoHeight > 0, (videoWidth, videoHeight) != cropFrame {
            cropFrame = (videoWidth, videoHeight)
            if !cropPreset.isEmpty { applyVideoAdjustments() }
        }
        chapterIndex = ChapterNav.index(at: position, chapters: chapters)
        if tickCount % 5 == 0 { refreshChapters() }
        audioTrackID = engine.intProp("aid") ?? audioTrackID
        subtitleTrackID = engine.intProp("sid") ?? subtitleTrackID
        tickCount += 1
        if !opening {
            endGate.noteProgress(position: position, duration: duration)
        }
        if fitOnLoad, videoWidth > 8, videoHeight > 8, playbackWindow?.styleMask.contains(.fullScreen) != true, !pictureInPicture {
            fitOnLoad = false
            let limit = screenLimit()
            applyFrame(WindowFit.fitted(
                videoWidth: videoWidth,
                videoHeight: videoHeight,
                maxWidth: limit.width,
                maxHeight: limit.height
            ), label: "Window sized to video")
        }
        syncFloatingAspect()
        if tickCount % 5 == 0 { NowPlayingService.shared.update(model: self) }
        if tickCount % 25 == 0 { saveResume() }
        evaluateChrome(reason: "tick")
    }

    private func saveResume() {
        guard let current = playlist.current else { return }
        resume.remember(position: position, duration: duration, for: ResumeStore.key(for: current.url))
    }

    private func refreshTracks() {
        tracks = engine?.tracks() ?? []
        let realVideo = tracks.contains { $0.kind == "video" && !$0.albumArt }
        showsVideo = tracks.isEmpty ? true : realVideo
        audioTrackID = engine?.intProp("aid") ?? 0
        subtitleTrackID = engine?.intProp("sid") ?? 0
    }

    private func refreshChapters() {
        let next = engine?.chapters() ?? []
        if next != chapters { chapters = next }
        if chapters.count != loggedChapterCount {
            loggedChapterCount = chapters.count
            uiLog.info("chapters \(self.chapters.count, privacy: .public)")
        }
        chapterIndex = ChapterNav.index(at: position, chapters: chapters)
    }

    private func refreshMetadata() {
        mediaTitle = engine?.stringProp("media-title") ?? playlist.current?.title ?? ""
        artist = engine?.stringProp("metadata/by-key/Artist")
            ?? engine?.stringProp("metadata/by-key/artist")
            ?? engine?.stringProp("metadata/by-key/ARTIST")
            ?? ""
        album = engine?.stringProp("metadata/by-key/Album")
            ?? engine?.stringProp("metadata/by-key/album")
            ?? engine?.stringProp("metadata/by-key/ALBUM")
            ?? ""
        loadLyrics()
    }

    private func loadLyrics() {
        lyrics = []
        lyricPlain = ""
        let embedded = engine?.stringProp("metadata/by-key/LYRICS")
            ?? engine?.stringProp("metadata/by-key/lyrics")
            ?? engine?.stringProp("metadata/by-key/Lyrics")
            ?? ""
        if !embedded.isEmpty {
            let parsed = LyricsFile.parse(embedded)
            if parsed.isEmpty { lyricPlain = embedded } else { lyrics = parsed }
        }
        if lyrics.isEmpty, lyricPlain.isEmpty, let url = playlist.current?.url, url.isFileURL {
            let sidecar = url.deletingPathExtension().appendingPathExtension("lrc")
            if let text = try? String(contentsOf: sidecar, encoding: .utf8) {
                lyrics = LyricsFile.parse(text)
            }
        }
    }

    private func loadArtworkIfNeeded() {
        artwork = nil
        guard !showsVideo, let current = playlist.current else { return }
        let url = current.url
        let engine = self.engine
        if url.isFileURL {
            Task { @MainActor in
                let asset = AVURLAsset(url: url)
                if let metadata = try? await asset.load(.commonMetadata) {
                    for item in metadata where item.commonKey == .commonKeyArtwork {
                        if let data = try? await item.load(.dataValue), let image = NSImage(data: data) {
                            self.artwork = image
                            NowPlayingService.shared.update(model: self)
                            return
                        }
                    }
                }
                self.captureAttachedPicture(using: engine)
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
                self?.captureAttachedPicture(using: engine)
            }
        }
    }

    private func captureAttachedPicture(using engine: MPVController?) {
        guard artwork == nil, !showsVideo, playlist.current != nil else { return }
        guard tracks.contains(where: { $0.kind == "video" && $0.albumArt }) else { return }
        guard let data = engine?.capturePNG(), let image = NSImage(data: data), image.size.width > 1 else { return }
        artwork = image
        NowPlayingService.shared.update(model: self)
        uiLog.info("album art taken from attached picture")
    }

    private func requestThumb(at time: Double) {
        guard let current = playlist.current, current.url.isFileURL else {
            showThumb = false
            thumbImage = nil
            return
        }
        thumbTime = time
        showThumb = true
        thumbTask?.cancel()
        let path = current.url.isFileURL ? current.url.path : current.url.absoluteString
        thumbTask = Task {
            try? await Task.sleep(nanoseconds: 160_000_000)
            guard !Task.isCancelled else { return }
            ThumbnailService.shared.request(path: path, time: time) { [weak self] image in
                guard let self, self.thumbTime == time else { return }
                self.thumbImage = image
            }
        }
    }

    private func showStatus(_ text: String, progress: Double? = nil, mark: StatusMark = .generic) {
        statusText = text
        statusProgress = progress
        statusMark = mark
        uiLog.info("osd \(text, privacy: .public)")
        statusToken = UUID()
        let token = statusToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self, self.statusToken == token else { return }
            self.statusText = nil
            self.statusProgress = nil
            self.statusMark = .generic
        }
    }

    private func clearTransport() {
        opening = false
        buffering = false
        showsVideo = true
        position = 0
        duration = 0
        paused = true
        artwork = nil
        artist = ""
        album = ""
        lyrics = []
        lyricPlain = ""
        tracks = []
        chapters = []
        chapterIndex = -1
        loggedChapterCount = -1
        updateActivity()
        NowPlayingService.shared.update(model: self)
    }

    private func updateActivity() {
        let playing = !paused && playlist.current != nil
        if playing && activity == nil {
            activity = ProcessInfo.processInfo.beginActivity(
                options: [.userInitiated, .idleSystemSleepDisabled],
                reason: "Playing media"
            )
        } else if !playing, let activity {
            ProcessInfo.processInfo.endActivity(activity)
            self.activity = nil
        }
    }

    private func enterPictureInPicture() {
        let ratio = (videoWidth > 0 && videoHeight > 0) ? CGFloat(videoWidth) / CGFloat(videoHeight) : 16 / 9
        let width: CGFloat = 480
        let height = max(120, (width / ratio).rounded())
        let panel = NSPanel(
            contentRect: NSRect(x: 80, y: 80, width: width, height: height),
            styleMask: [.titled, .closable, .resizable, .utilityWindow, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "Meowx"
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = false
        let host = NSView()
        host.wantsLayer = true
        host.layer?.backgroundColor = NSColor.black.cgColor
        panel.contentView = host
        if videoWidth > 0, videoHeight > 0 {
            panel.contentAspectRatio = NSSize(width: videoWidth, height: videoHeight)
        }
        videoView.removeFromSuperview()
        host.addSubview(videoView)
        videoView.frame = host.bounds
        videoView.autoresizingMask = [.width, .height]
        panel.delegate = pipDelegate
        panel.makeKeyAndOrderFront(nil)
        pipPanel = panel
        pictureInPicture = true
        uiLog.info("floating window shown")
    }

    private func expand(_ url: URL) -> [PlaylistItem] {
        if url.isFileURL {
            var directory: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &directory), directory.boolValue {
                if FileManager.default.fileExists(atPath: url.appendingPathComponent("VIDEO_TS").path) {
                    return [PlaylistItem(url: url, title: url.lastPathComponent)]
                }
                let children = (try? FileManager.default.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                )) ?? []
                return children
                    .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) != true }
                    .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
                    .flatMap { expand($0) }
            }
            if MediaFiles.isM3U(url), let text = try? String(contentsOf: url, encoding: .utf8) {
                let parsed = Playlist.parseM3U(text, relativeTo: url.deletingLastPathComponent())
                if !parsed.isEmpty { return parsed }
            }
        }
        return [PlaylistItem(url: url)]
    }

    private static func which(_ name: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [name]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return nil
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let path, !path.isEmpty else { return nil }
        return path
    }

    @objc private func screenChanged(_ notification: Notification) {
        fullscreen = notification.name == NSWindow.didEnterFullScreenNotification
        uiLog.info("fullscreen \(self.fullscreen ? "enter" : "exit", privacy: .public)")
        if !fullscreen { poke() } else { evaluateChrome(reason: "fullscreen") }
    }

    @objc private func menuBegan(_ notification: Notification) {
        menuOpen = true
        uiLog.info("menu began")
        evaluateChrome(reason: "menu")
    }

    @objc private func menuEnded(_ notification: Notification) {
        menuOpen = false
        uiLog.info("menu ended")
        poke()
    }
}

extension PlayerModel: EngineDelegate {
    func engineFileLoaded() {
        opening = false
        endGate.fileDidLoad()
        fitOnLoad = settings.resizeToVideoOnOpen
        refreshTracks()
        refreshMetadata()
        engine?.apply(settings)
        applyVideoAdjustments()
        refreshChapters()
        if resumeOnLoad, let current = playlist.current {
            let key = ResumeStore.key(for: current.url)
            if let saved = resume.position(for: key), saved > 3 {
                engine?.seekAbsolute(saved, exact: true)
                showStatus("Resumed at \(TimeFormat.string(saved))")
            }
        }
        loadArtworkIfNeeded()
        NowPlayingService.shared.update(model: self)
        videoView.markFramePending()
        evaluateChrome(reason: "file-loaded")
    }

    func engineEnded(_ end: EngineEnd) {
        switch end {
        case .stop:
            return
        case .error(let message):
            opening = false
            buffering = false
            errorMessage = "Couldn't play this file. \(message)"
            errorTitle = "Can't play this"
            errorURL = playlist.current?.url
            errorItemID = playlist.current?.id
            evaluateChrome(reason: "error")
        case .eof:
            guard endGate.consume(reached: true) else { return }
            if fileLoop { return }
            saveResume()
            switch playlist.afterEndOfFile() {
            case .play(let item):
                load(item, resume: playlist.repeatMode != .one)
            case .stop:
                pause()
                showStatus("End")
                evaluateChrome(reason: "eof")
            }
        }
    }

    func enginePauseChanged(_ value: Bool) {
        paused = value
        if paused { evaluateChrome(reason: "pause") } else { poke() }
        updateActivity()
        videoView.updateTouchBar()
    }

    func engineBufferingChanged(_ value: Bool) {
        buffering = value
    }

    func engineTracksChanged() {
        refreshTracks()
        announceTracksIfNeeded()
        evaluateChrome(reason: "tracks")
    }

    private func announceTracksIfNeeded() {
        guard let kind = pendingTrackAnnouncement else { return }
        pendingTrackAnnouncement = nil
        if kind == "sub" {
            let name = subtitleTrackID <= 0 ? "Subtitles off" : (subtitleTracks.first { $0.id == subtitleTrackID }?.label ?? "Subtitles off")
            flashStatus(name, mark: .track)
        } else if kind == "audio" {
            flashStatus(audioTracks.first { $0.id == audioTrackID }?.label ?? "Audio", mark: .track)
        }
    }
}

final class PiPCloseDelegate: NSObject, NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        PlayerModel.shared.finishPictureInPicture()
    }
}
