import AppKit
import MeowxCore
import os

/// Right-click menu for the video. Every item calls a real action. Unimplemented video adjustments are omitted.
enum VideoContextMenu {
    private static let log = Logger(subsystem: "com.cappy7.meowx", category: "ui")

    static func make() -> NSMenu {
        let model = PlayerModel.shared
        let menu = NSMenu()
        menu.autoenablesItems = false
        if model.playlist.current == nil {
            menu.addItem(item("Open…", key: "o", modifiers: .command, action: #selector(VideoMenuActions.openFiles)))
            menu.addItem(item("Open URL…", key: "u", modifiers: .command, action: #selector(VideoMenuActions.openURL)))
            menu.addItem(recentMenu())
            log.info("context menu built for empty player, \(menu.items.count, privacy: .public) items")
            return menu
        }

        let playing = !model.paused
        menu.addItem(item(playing ? "Pause" : "Play", key: " ", action: #selector(VideoMenuActions.togglePause)))
        menu.addItem(item("Previous", key: arrow(.left), modifiers: .command, action: #selector(VideoMenuActions.previous)))
        menu.addItem(item("Next", key: arrow(.right), modifiers: .command, action: #selector(VideoMenuActions.next)))
        menu.addItem(.separator())

        let seek = NSMenu()
        seek.addItem(item("Back 5 Seconds", key: arrow(.left), action: #selector(VideoMenuActions.back5)))
        seek.addItem(item("Forward 5 Seconds", key: arrow(.right), action: #selector(VideoMenuActions.forward5)))
        seek.addItem(item("Back 30 Seconds", key: arrow(.left), modifiers: .shift, action: #selector(VideoMenuActions.back30)))
        seek.addItem(item("Forward 30 Seconds", key: arrow(.right), modifiers: .shift, action: #selector(VideoMenuActions.forward30)))
        seek.addItem(item("Go to Time…", key: "j", modifiers: .command, action: #selector(VideoMenuActions.goToTime)))
        seek.addItem(item("Start", key: functionKey(0xF729), action: #selector(VideoMenuActions.goToStart)))
        seek.addItem(item("End", key: functionKey(0xF72B), action: #selector(VideoMenuActions.goToEnd)))
        menu.addItem(submenu("Seek", seek))
        menu.addItem(submenu("Chapters", chaptersMenu(model)))

        let speed = NSMenu()
        for step in PlayerModel.speedSteps {
            let title = step.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0fx", step) : String(format: "%.2gx", step)
            let on = abs(model.speed - step) < 0.02
            speed.addItem(item(title, state: on ? .on : .off, action: #selector(VideoMenuActions.pickSpeed(_:)), represented: NSNumber(value: step)))
        }
        speed.addItem(.separator())
        speed.addItem(item("Reset", key: "\\", action: #selector(VideoMenuActions.resetSpeed)))
        menu.addItem(submenu("Speed", speed))

        let audio = NSMenu()
        if model.audioTracks.isEmpty {
            audio.addItem(disabled("None available"))
        } else {
            for track in model.audioTracks {
                audio.addItem(item(track.label, state: track.id == model.audioTrackID ? .on : .off, action: #selector(VideoMenuActions.pickAudio(_:)), represented: NSNumber(value: track.id)))
            }
        }
        audio.addItem(.separator())
        audio.addItem(disabled(String(format: "Audio delay: %+.1f s", model.audioDelay)))
        audio.addItem(item("Delay Earlier", key: "z", modifiers: .option, action: #selector(VideoMenuActions.audioEarlier)))
        audio.addItem(item("Delay Later", key: "x", modifiers: .option, action: #selector(VideoMenuActions.audioLater)))
        audio.addItem(item("Mute", key: "m", state: model.muted ? .on : .off, action: #selector(VideoMenuActions.toggleMute)))
        menu.addItem(submenu("Audio", audio))

        let subs = NSMenu()
        subs.addItem(item("Off", state: model.subtitleTrackID <= 0 ? .on : .off, action: #selector(VideoMenuActions.subtitlesOff)))
        subs.addItem(item(model.subtitlesHidden ? "Show Subtitles" : "Hide Subtitles", key: "v", action: #selector(VideoMenuActions.toggleSubtitleVisibility)))
        if model.subtitleTracks.isEmpty {
            subs.addItem(disabled("None available"))
        } else {
            for track in model.subtitleTracks {
                subs.addItem(item(track.label, state: track.id == model.subtitleTrackID ? .on : .off, action: #selector(VideoMenuActions.pickSubtitle(_:)), represented: NSNumber(value: track.id)))
            }
        }
        subs.addItem(.separator())
        subs.addItem(item("Add Subtitle File…", action: #selector(VideoMenuActions.addSubtitle)))
        subs.addItem(item("Search Online…", action: #selector(VideoMenuActions.searchSubtitles)))
        subs.addItem(disabled(String(format: "Subtitle delay: %+.1f s", model.subDelay)))
        subs.addItem(item("Delay Earlier", key: "z", action: #selector(VideoMenuActions.subEarlier)))
        subs.addItem(item("Delay Later", key: "x", action: #selector(VideoMenuActions.subLater)))
        subs.addItem(disabled("Size \(Int(model.settings.subtitleSize.rounded()))"))
        subs.addItem(item("Size Smaller", action: #selector(VideoMenuActions.sizeSmaller)))
        subs.addItem(item("Size Larger", action: #selector(VideoMenuActions.sizeLarger)))
        menu.addItem(submenu("Subtitles", subs))

        let video = NSMenu()
        video.addItem(item("Rotate 90°", key: "r", action: #selector(VideoMenuActions.rotate)))
        video.addItem(submenu("Aspect Ratio", aspectMenu(model)))
        video.addItem(item("Flip Horizontal", key: "r", modifiers: .shift, state: model.flipHorizontal ? .on : .off, action: #selector(VideoMenuActions.flipHorizontal)))
        video.addItem(item("Flip Vertical", key: "r", modifiers: .option, state: model.flipVertical ? .on : .off, action: #selector(VideoMenuActions.flipVertical)))
        video.addItem(submenu("Crop", cropMenu(model)))
        video.addItem(item("Deinterlace", key: "d", state: model.deinterlace ? .on : .off, action: #selector(VideoMenuActions.deinterlace)))
        video.addItem(item("Reset Zoom and Pan", key: "g", action: #selector(VideoMenuActions.resetZoom)))
        video.addItem(item("Picture Adjustments", key: "c", state: model.pictureOpen ? .on : .off, action: #selector(VideoMenuActions.picture)))
        menu.addItem(submenu("Video", video))

        menu.addItem(item("Full Screen", key: "f", state: model.fullscreen ? .on : .off, action: #selector(VideoMenuActions.fullScreen)))
        menu.addItem(item("Floating Window", key: "p", state: model.pictureInPicture ? .on : .off, action: #selector(VideoMenuActions.pictureInPicture)))
        menu.addItem(item("Always on Top", key: "t", modifiers: .command, state: model.alwaysOnTop ? .on : .off, action: #selector(VideoMenuActions.alwaysOnTop)))
        menu.addItem(item("Screenshot", key: "s", modifiers: [.command, .shift], action: #selector(VideoMenuActions.screenshot)))
        menu.addItem(item("Stats", key: "i", state: model.statsVisible ? .on : .off, action: #selector(VideoMenuActions.stats)))
        menu.addItem(.separator())
        if model.playlist.current?.url.isFileURL == true {
            menu.addItem(item("Show in Finder", action: #selector(VideoMenuActions.reveal)))
        }
        menu.addItem(item(model.playlist.current?.url.isFileURL == true ? "Copy File Path" : "Copy URL", action: #selector(VideoMenuActions.copyLocation)))
        menu.addItem(.separator())
        menu.addItem(item("Open…", key: "o", modifiers: .command, action: #selector(VideoMenuActions.openFiles)))
        menu.addItem(item("Open URL…", key: "u", modifiers: .command, action: #selector(VideoMenuActions.openURL)))
        menu.addItem(item(model.playlistShown ? "Hide Playlist" : "Show Playlist", action: #selector(VideoMenuActions.togglePlaylist)))
        log.info("context menu built, \(menu.items.count, privacy: .public) top-level items")
        return menu
    }

    private static func chaptersMenu(_ model: PlayerModel) -> NSMenu {
        let menu = NSMenu()
        menu.addItem(item("Previous", key: functionKey(0xF72C), action: #selector(VideoMenuActions.previousChapter)))
        menu.addItem(item("Next", key: functionKey(0xF72D), action: #selector(VideoMenuActions.nextChapter)))
        menu.addItem(.separator())
        if model.chapters.isEmpty {
            menu.addItem(disabled("No chapters"))
        } else {
            for chapter in model.chapters {
                let name = ChapterNav.displayTitle(index: chapter.index, title: chapter.title)
                let title = "\(name)  \(TimeFormat.string(chapter.time))"
                menu.addItem(item(
                    title,
                    state: chapter.index == model.chapterIndex ? .on : .off,
                    action: #selector(VideoMenuActions.pickChapter(_:)),
                    represented: NSNumber(value: chapter.index)
                ))
            }
        }
        return menu
    }

    private static func aspectMenu(_ model: PlayerModel) -> NSMenu {
        let menu = NSMenu()
        for preset in AspectCycle.presets {
            let title = preset.isEmpty ? "Default" : preset
            menu.addItem(item(
                title,
                state: model.aspectOverride == preset ? .on : .off,
                action: #selector(VideoMenuActions.pickAspect(_:)),
                represented: preset
            ))
        }
        menu.addItem(item("Cycle", key: "e", action: #selector(VideoMenuActions.cycleAspect)))
        return menu
    }

    private static func cropMenu(_ model: PlayerModel) -> NSMenu {
        let menu = NSMenu()
        for preset in CropPreset.order {
            let title = preset.isEmpty ? "None" : preset
            menu.addItem(item(
                title,
                state: model.cropPreset == preset ? .on : .off,
                action: #selector(VideoMenuActions.pickCrop(_:)),
                represented: preset
            ))
        }
        menu.addItem(item("Cycle", key: "e", modifiers: .shift, action: #selector(VideoMenuActions.cycleCrop)))
        return menu
    }

    private static func recentMenu() -> NSMenuItem {
        let menu = NSMenu()
        let urls = NSDocumentController.shared.recentDocumentURLs
        if urls.isEmpty {
            menu.addItem(disabled("None"))
        } else {
            for url in urls.prefix(10) {
                menu.addItem(item(url.lastPathComponent, action: #selector(VideoMenuActions.openRecent(_:)), represented: url))
            }
            menu.addItem(.separator())
            menu.addItem(item("Clear Menu", action: #selector(VideoMenuActions.clearRecent)))
        }
        return submenu("Open Recent", menu)
    }

    private static func submenu(_ title: String, _ menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = menu
        return item
    }

    private static func disabled(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private static func item(
        _ title: String,
        key: String = "",
        modifiers: NSEvent.ModifierFlags = [],
        state: NSControl.StateValue = .off,
        action: Selector,
        represented: Any? = nil
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        item.state = state
        item.target = VideoMenuActions.shared
        item.isEnabled = true
        item.representedObject = represented
        return item
    }

    private enum Arrow { case left, right }
    private static func arrow(_ side: Arrow) -> String {
        let value: UInt32 = side == .left ? 0xF702 : 0xF703
        guard let scalar = UnicodeScalar(value) else { return "" }
        return String(scalar)
    }

    private static func functionKey(_ value: UInt32) -> String {
        guard let scalar = UnicodeScalar(value) else { return "" }
        return String(scalar)
    }
}

final class VideoMenuActions: NSObject {
    static let shared = VideoMenuActions()

    @objc func togglePause() { PlayerModel.shared.togglePause() }
    @objc func previous() { PlayerModel.shared.previous(); PlayerModel.shared.poke() }
    @objc func next() { PlayerModel.shared.next(); PlayerModel.shared.poke() }
    @objc func back5() { PlayerModel.shared.seek(by: -5) }
    @objc func forward5() { PlayerModel.shared.seek(by: 5) }
    @objc func back30() { PlayerModel.shared.seek(by: -30) }
    @objc func forward30() { PlayerModel.shared.seek(by: 30) }
    @objc func goToTime() { PlayerModel.shared.timePrompt = true; PlayerModel.shared.poke() }
    @objc func goToStart() { PlayerModel.shared.seekToStart() }
    @objc func goToEnd() { PlayerModel.shared.seekToEnd() }
    @objc func resetSpeed() { PlayerModel.shared.resetSpeed() }
    @objc func pickSpeed(_ sender: NSMenuItem) {
        guard let speed = (sender.representedObject as? NSNumber)?.doubleValue else { return }
        PlayerModel.shared.setSpeed(speed)
    }
    @objc func pickAudio(_ sender: NSMenuItem) {
        guard let id = (sender.representedObject as? NSNumber)?.intValue else { return }
        PlayerModel.shared.selectAudio(id)
    }
    @objc func pickSubtitle(_ sender: NSMenuItem) {
        guard let id = (sender.representedObject as? NSNumber)?.intValue else { return }
        PlayerModel.shared.selectSubtitle(id)
    }
    @objc func subtitlesOff() { PlayerModel.shared.selectSubtitle(0) }
    @objc func toggleSubtitleVisibility() { PlayerModel.shared.toggleSubtitleVisibility() }
    @objc func audioEarlier() { PlayerModel.shared.nudgeAudioDelay(-0.1) }
    @objc func audioLater() { PlayerModel.shared.nudgeAudioDelay(0.1) }
    @objc func subEarlier() { PlayerModel.shared.nudgeSubDelay(-0.1) }
    @objc func subLater() { PlayerModel.shared.nudgeSubDelay(0.1) }
    @objc func sizeSmaller() { PlayerModel.shared.nudgeSubtitleSize(-4) }
    @objc func sizeLarger() { PlayerModel.shared.nudgeSubtitleSize(4) }
    @objc func toggleMute() { PlayerModel.shared.toggleMute() }
    @objc func rotate() { PlayerModel.shared.rotateClockwise() }
    @objc func cycleAspect() { PlayerModel.shared.cycleAspect() }
    @objc func pickAspect(_ sender: NSMenuItem) {
        PlayerModel.shared.setAspect(sender.representedObject as? String ?? "")
    }
    @objc func flipHorizontal() { PlayerModel.shared.toggleFlipHorizontal() }
    @objc func flipVertical() { PlayerModel.shared.toggleFlipVertical() }
    @objc func pickCrop(_ sender: NSMenuItem) {
        PlayerModel.shared.setCrop(sender.representedObject as? String ?? "")
    }
    @objc func cycleCrop() { PlayerModel.shared.cycleCrop() }
    @objc func deinterlace() { PlayerModel.shared.toggleDeinterlace() }
    @objc func resetZoom() { PlayerModel.shared.resetZoomAndPan() }
    @objc func picture() { PlayerModel.shared.togglePicturePanel() }
    @objc func previousChapter() { PlayerModel.shared.stepChapter(-1) }
    @objc func nextChapter() { PlayerModel.shared.stepChapter(1) }
    @objc func pickChapter(_ sender: NSMenuItem) {
        guard let index = (sender.representedObject as? NSNumber)?.intValue else { return }
        PlayerModel.shared.seekChapter(index)
    }
    @objc func addSubtitle() { PlayerModel.shared.openSubtitleFile() }
    @objc func searchSubtitles() { PlayerModel.shared.searchOpen = true; PlayerModel.shared.poke() }
    @objc func fullScreen() { PlayerModel.shared.toggleFullscreen(); PlayerModel.shared.poke() }
    @objc func pictureInPicture() { PlayerModel.shared.togglePictureInPicture(); PlayerModel.shared.poke() }
    @objc func alwaysOnTop() { PlayerModel.shared.toggleAlwaysOnTop(); PlayerModel.shared.poke() }
    @objc func screenshot() { PlayerModel.shared.screenshot(); PlayerModel.shared.poke() }
    @objc func stats() { PlayerModel.shared.toggleStats(); PlayerModel.shared.poke() }
    @objc func reveal() { PlayerModel.shared.revealCurrent(); PlayerModel.shared.poke() }
    @objc func copyLocation() { PlayerModel.shared.copyCurrentLocation() }
    @objc func openFiles() { PlayerModel.shared.openFiles(playNow: true) }
    @objc func openURL() { PlayerModel.shared.urlPrompt = true; PlayerModel.shared.poke() }
    @objc func togglePlaylist() {
        PlayerModel.shared.playlistShown.toggle()
        PlayerModel.shared.poke()
    }
    @objc func openRecent(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        PlayerModel.shared.add(urls: [url], playNow: true)
    }
    @objc func clearRecent() { NSDocumentController.shared.clearRecentDocuments(nil) }
}
