import AppKit
import MeowxCore
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
        guard let token = Self.token(for: event.keyCode) else { return false }
        let input = ShortcutInput(
            token: token,
            command: flags.contains(.command),
            shift: flags.contains(.shift)
        )
        guard let shortcut = ShortcutCatalog.match(input) else { return false }
        let model = PlayerModel.shared
        if shortcut.id == "leaveFullScreen", !model.fullscreen { return false }
        uiLog.debug("shortcut \(shortcut.id, privacy: .public)")
        model.performShortcut(shortcut.id)
        return true
    }

    private static func token(for keyCode: UInt16) -> String? {
        switch keyCode {
        case 49: return "space"
        case 123: return "left"
        case 124: return "right"
        case 125: return "down"
        case 126: return "up"
        case 53: return "escape"
        case 0: return "a"
        case 1: return "s"
        case 3: return "f"
        case 17: return "t"
        case 31: return "o"
        case 32: return "u"
        case 34: return "i"
        case 35: return "p"
        case 38: return "j"
        case 30: return "bracketright"
        case 33: return "bracketleft"
        case 42: return "backslash"
        case 43: return "comma"
        case 46: return "m"
        case 47: return "period"
        default: return nil
        }
    }

    private static var isTyping: Bool {
        guard let responder = NSApp.keyWindow?.firstResponder else { return false }
        return responder is NSTextView || responder is NSTextField
    }
}
