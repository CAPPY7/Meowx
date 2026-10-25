import MeowxCore
import SwiftUI

@main
struct MeowxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        MeowxSelfTest.runIfRequested()
    }

    var body: some Scene {
        Window("Meowx", id: "main") {
            ContentView()
        }
        .defaultSize(width: 1120, height: 720)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            AboutCommands()
            MeowxCommands()
        }

        Window("About Meowx", id: "about") {
            AboutView()
        }
        .defaultSize(width: 360, height: 320)
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
        }
    }
}

struct AboutCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About Meowx") { openWindow(id: "about") }
        }
    }
}

struct MeowxCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Open…") { PlayerModel.shared.openFiles(playNow: true) }
                .keyboardShortcut("o")
            Button("Open URL…") { PlayerModel.shared.urlPrompt = true }
                .keyboardShortcut("u")
            Button("Add to Playlist…") { PlayerModel.shared.openFiles(playNow: false) }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            Button("Add Subtitle…") { PlayerModel.shared.openSubtitleFile() }
            Divider()
            Button("Save Playlist…") { PlayerModel.shared.savePlaylist() }
                .disabled(PlayerModel.shared.playlist.items.isEmpty)
        }
        CommandMenu("Playback") {
            Button(menuTitle("Play/Pause", "playPause")) { PlayerModel.shared.togglePause() }
            Button("Next") { PlayerModel.shared.next() }
                .keyboardShortcut(.rightArrow, modifiers: .command)
            Button("Previous") { PlayerModel.shared.previous() }
                .keyboardShortcut(.leftArrow, modifiers: .command)
            Divider()
            Button(menuTitle("Seek Forward", "seekForward")) { PlayerModel.shared.seek(by: PlayerModel.shared.settings.seekShort) }
            Button(menuTitle("Seek Backward", "seekBack")) { PlayerModel.shared.seek(by: -PlayerModel.shared.settings.seekShort) }
            Button(menuTitle("Seek Forward Further", "seekForward30")) { PlayerModel.shared.seek(by: PlayerModel.shared.settings.seekLong) }
            Button(menuTitle("Seek Backward Further", "seekBack30")) { PlayerModel.shared.seek(by: -PlayerModel.shared.settings.seekLong) }
            Button(menuTitle("Go to Start", "seekStart")) { PlayerModel.shared.seekToStart() }
            Button(menuTitle("Go to End", "seekEnd")) { PlayerModel.shared.seekToEnd() }
            Button(menuTitle("Previous Chapter", "previousChapter")) { PlayerModel.shared.stepChapter(-1) }
            Button(menuTitle("Next Chapter", "nextChapter")) { PlayerModel.shared.stepChapter(1) }
            Button("Go to Time…") { PlayerModel.shared.timePrompt = true }
                .keyboardShortcut("j")
            Button(menuTitle("Next Frame", "frameForward")) { PlayerModel.shared.frameStep(backward: false) }
            Button(menuTitle("Previous Frame", "frameBack")) { PlayerModel.shared.frameStep(backward: true) }
            Divider()
            Button(menuTitle("Speed Up", "speedUp")) { PlayerModel.shared.nudgeSpeed(1) }
            Button(menuTitle("Speed Down", "speedDown")) { PlayerModel.shared.nudgeSpeed(-1) }
            Button(menuTitle("Reset Speed", "speedReset")) { PlayerModel.shared.resetSpeed() }
            Divider()
            Button(menuTitle("Cycle Subtitles", "cycleSubtitles")) { PlayerModel.shared.cycleSubtitles() }
            Button(menuTitle("Previous Subtitle", "previousSubtitle")) { PlayerModel.shared.previousSubtitle() }
            Button(menuTitle("Show or Hide Subtitles", "toggleSubtitleVisibility")) { PlayerModel.shared.toggleSubtitleVisibility() }
            Button(menuTitle("Subtitle Earlier", "subDelayEarlier")) { PlayerModel.shared.nudgeSubDelay(-0.1) }
            Button(menuTitle("Subtitle Later", "subDelayLater")) { PlayerModel.shared.nudgeSubDelay(0.1) }
            Button(menuTitle("Cycle Audio", "cycleAudio")) { PlayerModel.shared.cycleAudio() }
            Button(menuTitle("Previous Audio", "previousAudio")) { PlayerModel.shared.previousAudio() }
            Button(menuTitle("Audio Earlier", "audioDelayEarlier")) { PlayerModel.shared.nudgeAudioDelay(-0.1) }
            Button(menuTitle("Audio Later", "audioDelayLater")) { PlayerModel.shared.nudgeAudioDelay(0.1) }
            Button(menuTitle("Volume Up", "volumeUp")) { PlayerModel.shared.nudgeVolume(5) }
            Button(menuTitle("Volume Up 10", "volumeUp10")) { PlayerModel.shared.nudgeVolume(10) }
            Button(menuTitle("Volume Down", "volumeDown")) { PlayerModel.shared.nudgeVolume(-5) }
            Button(menuTitle("Volume Down 10", "volumeDown10")) { PlayerModel.shared.nudgeVolume(-10) }
            Button(menuTitle("Mute", "mute")) { PlayerModel.shared.toggleMute() }
            Button("Screenshot") { PlayerModel.shared.screenshot() }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            Divider()
            Button(menuTitle("Set Loop A, then B, then Clear", "loopCycle")) { PlayerModel.shared.cycleLoopPoint() }
            Button(menuTitle("Loop Current File", "loopFile")) { PlayerModel.shared.toggleFileLoop() }
        }
        CommandMenu("Video") {
            Button(menuTitle("Full Screen", "fullScreen")) { PlayerModel.shared.toggleFullscreen() }
            Button(menuTitle("Rotate 90°", "rotate")) { PlayerModel.shared.rotateClockwise() }
            Button(menuTitle("Cycle Aspect Ratio", "cycleAspect")) { PlayerModel.shared.cycleAspect() }
            Button(menuTitle("Flip Horizontal", "flipHorizontal")) { PlayerModel.shared.toggleFlipHorizontal() }
            Button(menuTitle("Flip Vertical", "flipVertical")) { PlayerModel.shared.toggleFlipVertical() }
            Button(menuTitle("Cycle Crop", "cycleCrop")) { PlayerModel.shared.cycleCrop() }
            Button(menuTitle("Deinterlace", "deinterlace")) { PlayerModel.shared.toggleDeinterlace() }
            Button(menuTitle("Reset Zoom and Pan", "resetZoom")) { PlayerModel.shared.resetZoomAndPan() }
            Button(menuTitle("Picture Adjustments", "picture")) { PlayerModel.shared.togglePicturePanel() }
            Button("Half Size") { PlayerModel.shared.resizeWindow(scale: 0.5) }
                .keyboardShortcut("1")
            Button("Actual Size") { PlayerModel.shared.resizeWindow(scale: 1) }
                .keyboardShortcut("2")
            Button("Double Size") { PlayerModel.shared.resizeWindow(scale: 2) }
                .keyboardShortcut("3")
            Button("Fit to Screen") { PlayerModel.shared.fitWindowToScreen() }
                .keyboardShortcut("0")
            Button(menuTitle("Floating Window", "pictureInPicture")) { PlayerModel.shared.togglePictureInPicture() }
            Button("Always on Top") { PlayerModel.shared.toggleAlwaysOnTop() }
                .keyboardShortcut("t", modifiers: .command)
            Button(menuTitle("Stats", "stats")) { PlayerModel.shared.toggleStats() }
            Button("Show in Finder") { PlayerModel.shared.revealCurrent() }
                .disabled(PlayerModel.shared.playlist.current?.url.isFileURL != true)
            Button("Set as Default Player") { PlayerModel.shared.makeDefaultPlayer() }
        }
        CommandGroup(after: .help) {
            Button("Keyboard Shortcuts") { PlayerModel.shared.shortcutPrompt = true }
        }
    }

    /// Bare keys stay off the menu so they cannot steal typing. Command shortcuts stay, because the menu column can show them safely.
    private func menuTitle(_ title: String, _ id: String) -> String {
        guard let command = ShortcutCatalog.command(id) else { return title }
        let shortcut = ShortcutMap.resolved(command, overrides: PlayerModel.shared.settings.shortcutOverrides)
        guard !shortcut.command, !shortcut.display.isEmpty else { return title }
        return "\(title) (\(shortcut.display))"
    }
}