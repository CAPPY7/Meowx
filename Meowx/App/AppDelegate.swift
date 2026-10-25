import AppKit
import os

final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let uiLog = Logger(subsystem: "com.cappy7.meowx", category: "ui")

    func applicationDidFinishLaunching(_ notification: Notification) {
        PlayerModel.shared.start()
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            Self.handle(event) ? nil : event
        }
        NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .scrollWheel]) { event in
            if event.window != nil {
                PlayerModel.shared.poke()
            }
            return event
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        PlayerModel.shared.start()
        PlayerModel.shared.add(urls: urls, playNow: true)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        PlayerModel.shared.prepareToQuit()
        return .terminateNow
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    private static func handle(_ event: NSEvent) -> Bool {
        if NSApp.modalWindow != nil { return false }
        if isTyping { return false }
        PlayerModel.shared.poke()
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.option) || flags.contains(.control) { return false }
        let command = flags.contains(.command)
        let shift = flags.contains(.shift)
        let model = PlayerModel.shared
        if command && shift && event.keyCode == 1 {
            model.screenshot()
            return true
        }
        if command && !shift && event.keyCode == 123 {
            model.previous()
            return true
        }
        if command && !shift && event.keyCode == 124 {
            model.next()
            return true
        }
        if command && !shift && event.keyCode == 38 {
            model.timePrompt = true
            return true
        }
        if command { return false }
        switch event.keyCode {
        case 49: model.togglePause()
        case 123: model.seek(by: shift ? -30 : -5)
        case 124: model.seek(by: shift ? 30 : 5)
        case 125: model.nudgeVolume(-5)
        case 126: model.nudgeVolume(5)
        case 46: model.toggleMute()
        case 3: model.toggleFullscreen()
        case 1: model.cycleSubtitles()
        case 0: model.cycleAudio()
        case 34: model.toggleStats()
        case 35: model.togglePictureInPicture()
        case 33: model.nudgeSpeed(-1)
        case 30: model.nudgeSpeed(1)
        case 42: model.resetSpeed()
        case 43: model.frameStep(backward: true)
        case 47: model.frameStep(backward: false)
        case 53:
            guard model.fullscreen else { return false }
            model.toggleFullscreen()
        default:
            return false
        }
        uiLog.debug("shortcut keyCode \(event.keyCode, privacy: .public)")
        return true
    }

    private static var isTyping: Bool {
        guard let responder = NSApp.keyWindow?.firstResponder else { return false }
        return responder is NSTextView || responder is NSTextField
    }
}
