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
        .commands { MeowxCommands() }

        Settings {
            SettingsView()
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
            Button("Play/Pause") { PlayerModel.shared.togglePause() }
                .keyboardShortcut(.space, modifiers: [])
            Button("Next") { PlayerModel.shared.next() }
                .keyboardShortcut(.rightArrow, modifiers: .command)
            Button("Previous") { PlayerModel.shared.previous() }
                .keyboardShortcut(.leftArrow, modifiers: .command)
            Divider()
            Button("Seek Forward 5 Seconds") { PlayerModel.shared.seek(by: 5) }
                .keyboardShortcut(.rightArrow, modifiers: [])
            Button("Seek Backward 5 Seconds") { PlayerModel.shared.seek(by: -5) }
                .keyboardShortcut(.leftArrow, modifiers: [])
            Button("Seek Forward 30 Seconds") { PlayerModel.shared.seek(by: 30) }
                .keyboardShortcut(.rightArrow, modifiers: .shift)
            Button("Seek Backward 30 Seconds") { PlayerModel.shared.seek(by: -30) }
                .keyboardShortcut(.leftArrow, modifiers: .shift)
            Button("Next Frame") { PlayerModel.shared.frameStep(backward: false) }
                .keyboardShortcut(".", modifiers: [])
            Button("Previous Frame") { PlayerModel.shared.frameStep(backward: true) }
                .keyboardShortcut(",", modifiers: [])
            Divider()
            Button("Speed Up") { PlayerModel.shared.nudgeSpeed(1) }
                .keyboardShortcut("]", modifiers: [])
            Button("Speed Down") { PlayerModel.shared.nudgeSpeed(-1) }
                .keyboardShortcut("[", modifiers: [])
            Button("Reset Speed") { PlayerModel.shared.resetSpeed() }
                .keyboardShortcut("\\", modifiers: [])
            Divider()
            Button("Cycle Subtitles") { PlayerModel.shared.cycleSubtitles() }
                .keyboardShortcut("s", modifiers: [])
            Button("Cycle Audio") { PlayerModel.shared.cycleAudio() }
                .keyboardShortcut("a", modifiers: [])
            Button("Volume Up") { PlayerModel.shared.nudgeVolume(5) }
                .keyboardShortcut(.upArrow, modifiers: [])
            Button("Volume Down") { PlayerModel.shared.nudgeVolume(-5) }
                .keyboardShortcut(.downArrow, modifiers: [])
            Button("Mute") { PlayerModel.shared.toggleMute() }
                .keyboardShortcut("m", modifiers: [])
            Button("Screenshot") { PlayerModel.shared.screenshot() }
                .keyboardShortcut("s", modifiers: [.command, .shift])
        }
        CommandMenu("Video") {
            Button("Full Screen") { PlayerModel.shared.toggleFullscreen() }
                .keyboardShortcut("f", modifiers: [])
            Button("Picture in Picture") { PlayerModel.shared.togglePictureInPicture() }
                .keyboardShortcut("p", modifiers: [])
            Button("Always on Top") { PlayerModel.shared.toggleAlwaysOnTop() }
                .keyboardShortcut("t", modifiers: .command)
            Button("Stats") { PlayerModel.shared.toggleStats() }
                .keyboardShortcut("i", modifiers: [])
            Button("Show in Finder") { PlayerModel.shared.revealCurrent() }
                .disabled(PlayerModel.shared.playlist.current?.url.isFileURL != true)
            Button("Set as Default Player") { PlayerModel.shared.makeDefaultPlayer() }
        }
        CommandGroup(after: .help) {
            Button("Keyboard Shortcuts") { PlayerModel.shared.shortcutPrompt = true }
        }
    }
}
