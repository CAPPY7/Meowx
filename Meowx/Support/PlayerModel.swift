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
    private var lastPoke = Date()
    private var lastHideSchedule = Date.distantPast
    private var hideWork: DispatchWorkItem?
    private let uiLog = Logger(subsystem: "com.cappy7.meowx", category: "ui")
    private var activity: NSObjectProtocol?
    private var pipPanel: NSPanel?
    private weak var mainHost: NSView?
    private let pipDelegate = PiPCloseDelegate()
    private(set) var ytdlpPath: String?

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
    var mediaTitle = ""
    var artwork: NSImage?
    var tracks: [MediaTrack] = []
    var audioTrackID = 0
    var subtitleTrackID = 0
    var subDelay = 0.0
    var audioDelay = 0.0
    var loopA: Double?
    var loopB: Double?
    var hwdec = ""
    var videoWidth = 0
    var videoHeight = 0
    var fps = 0.0
    var droppedFrames = 0
    var videoCodec = ""
    var audioCodec = ""
    var videoBitrate = 0.0
    var cacheSeconds = 0.0
    var statsVisible = false
    var chromeShown = true
    var controlsHovered = false
    var topHovered = false
    var menuOpen = false
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
    var shortcutPrompt = false
    var searchOpen = false
    var errorMessage: String?
    var statusText: String?
    var engineError: String?

    var displayTitle: String {
        if !mediaTitle.isEmpty { return mediaTitle }
        return playlist.current?.title ?? "Meowx"
    }

    var subtitleTracks: [MediaTrack] { tracks.filter { $0.kind == "sub" } }
    var audioTracks: [MediaTrack] { tracks.filter { $0.kind == "audio" } }

    private init() {
        settings = SettingsStore.load()
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
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.tick()
        }
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged(_:)), name: NSWindow.didEnterFullScreenNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged(_:)), name: NSWindow.didExitFullScreenNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(menuBegan(_:)), name: NSMenu.didBeginTrackingNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(menuEnded(_:)), name: NSMenu.didEndTrackingNotification, object: nil)
        evaluateChrome(reason: "start")
    }

    func prepareToQuit() {
        saveResume()
        timer?.invalidate()
        engine?.shutdown()
        engine = nil
        if let activity {
            ProcessInfo.processInfo.endActivity(activity)
        }
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
        var media: [PlaylistItem] = []
        var subtitles: [URL] = []
        for url in urls {
            let expanded = expand(url)
            for item in expanded {
                if MediaFiles.isSubtitle(item.url) {
                    subtitles.append(item.url)
                } else if !MediaFiles.isJunk(item.url) {
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
    }

    func cycleRepeat() {
        switch playlist.repeatMode {
        case .off: playlist.repeatMode = .all
        case .all: playlist.repeatMode = .one
        case .one: playlist.repeatMode = .off
        }
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
        }
    }

    func togglePause() {
        guard passGate() else { return }
        if playlist.current == nil {
            openFiles(playNow: true)
            return
        }
        if paused { play() } else { pause() }
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
        load(item, resume: true)
    }

    func previous() {
        guard allow("skip") else { return }
        if position > 3 {
            seek(to: 0, exact: true)
            return
        }
        guard let item = playlist.skipped(by: -1) else {
            seek(to: 0, exact: true)
            return
        }
        load(item, resume: true)
    }

    func seek(by delta: Double) {
        guard allow("seek") else { return }
        engine?.seekRelative(delta)
        position = max(0, position + delta)
        poke()
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
    }

    func toggleMute() {
        guard passGate() else { return }
        muted.toggle()
        engine?.setMuted(muted)
    }

    func setSpeed(_ value: Double) {
        speed = min(4, max(0.25, value))
        engine?.setSpeed(speed)
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
        engine?.cycle("sub")
    }

    func cycleAudio() {
        guard passGate() else { return }
        engine?.cycle("audio")
    }

    func selectSubtitle(_ id: Int) {
        subtitleTrackID = id
        engine?.selectTrack("sid", id: id)
    }

    func selectAudio(_ id: Int) {
        audioTrackID = id
        engine?.selectTrack("aid", id: id)
    }

    func nudgeSubDelay(_ delta: Double) {
        subDelay = engine?.nudge("sub-delay", by: delta) ?? (subDelay + delta)
    }

    func nudgeAudioDelay(_ delta: Double) {
        audioDelay = engine?.nudge("audio-delay", by: delta) ?? (audioDelay + delta)
    }

    func setLoopA() {
        loopA = position
        engine?.setString("ab-loop-a", String(format: "%.3f", position))
    }

    func setLoopB() {
        loopB = position
        engine?.setString("ab-loop-b", String(format: "%.3f", position))
    }

    func clearLoop() {
        loopA = nil
        loopB = nil
        engine?.setString("ab-loop-a", "no")
        engine?.setString("ab-loop-b", "no")
    }

    func toggleStats() {
        guard passGate() else { return }
        statsVisible.toggle()
    }

    func toggleFullscreen() {
        guard passGate() else { return }
        NSApp.mainWindow?.toggleFullScreen(nil)
    }

    func toggleAlwaysOnTop() {
        alwaysOnTop.toggle()
        NSApp.mainWindow?.level = alwaysOnTop ? .floating : .normal
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
    }

    func screenshot() {
        let folder = settings.resolvedScreenshotFolder
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let url = folder.appendingPathComponent("Meowx-\(stamp).\(settings.screenshotFormat.rawValue)")
        let saved = engine?.screenshot(to: url, format: settings.screenshotFormat.rawValue) == true
        if saved {
            showStatus("Saved screenshot")
        } else {
            errorMessage = "Couldn't save the screenshot."
        }
    }

    func updateSettings(_ body: (inout PlayerSettings) -> Void) {
        var copy = settings
        body(&copy)
        copy.cacheMegabytes = min(4096, max(32, copy.cacheMegabytes))
        copy.chromeHideDelay = PlayerSettings.clampedHideDelay(copy.chromeHideDelay)
        settings = copy
        SettingsStore.save(copy)
        engine?.apply(copy)
        evaluateChrome(reason: "settings")
    }

    func resetSettings() {
        settings = .default
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
            overlayOpen: urlPrompt || shortcutPrompt || searchOpen || menuOpen,
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
        mediaTitle = ""
        tracks = []
        loopA = nil
        loopB = nil
        subDelay = 0
        audioDelay = 0
        position = 0
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
        cacheSeconds = snap.cacheSeconds
        audioTrackID = engine.intProp("aid") ?? audioTrackID
        subtitleTrackID = engine.intProp("sid") ?? subtitleTrackID
        tickCount += 1
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

    private func refreshMetadata() {
        mediaTitle = engine?.stringProp("media-title") ?? playlist.current?.title ?? ""
        artist = engine?.stringProp("metadata/by-key/Artist")
            ?? engine?.stringProp("metadata/by-key/artist")
            ?? engine?.stringProp("metadata/by-key/ARTIST")
            ?? ""
    }

    private func loadArtworkIfNeeded() {
        artwork = nil
        guard !showsVideo, let url = playlist.current?.url, url.isFileURL else { return }
        Task {
            let asset = AVURLAsset(url: url)
            guard let metadata = try? await asset.load(.commonMetadata) else { return }
            for item in metadata where item.commonKey == .commonKeyArtwork {
                if let data = try? await item.load(.dataValue), let image = NSImage(data: data) {
                    self.artwork = image
                    NowPlayingService.shared.update(model: self)
                    return
                }
            }
        }
    }

    private func requestThumb(at time: Double) {
        guard let current = playlist.current else { return }
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

    private func showStatus(_ text: String) {
        statusText = text
        statusToken = UUID()
        let token = statusToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) { [weak self] in
            guard let self, self.statusToken == token else { return }
            self.statusText = nil
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
        tracks = []
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
        let panel = NSPanel(
            contentRect: NSRect(x: 96, y: 96, width: 480, height: 270),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = displayTitle
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
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
        panel.orderFrontRegardless()
        pipPanel = panel
        pictureInPicture = true
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
        refreshTracks()
        refreshMetadata()
        engine?.apply(settings)
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
            errorMessage = message
            evaluateChrome(reason: "error")
        case .eof:
            saveResume()
            switch playlist.afterEndOfFile() {
            case .play(let item):
                load(item, resume: playlist.repeatMode != .one)
            case .stop:
                pause()
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
        evaluateChrome(reason: "tracks")
    }
}

final class PiPCloseDelegate: NSObject, NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        PlayerModel.shared.finishPictureInPicture()
    }
}
