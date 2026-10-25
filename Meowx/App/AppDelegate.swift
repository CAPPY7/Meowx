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
        let routing = KeyRouting(
            appModal: NSApp.modalWindow != nil,
            sheetAttached: NSApp.windows.contains { $0.attachedSheet != nil } || NSApp.keyWindow?.isSheet == true,
            firstResponderIsText: NSApp.windows.contains { isText($0.firstResponder) }
        )
        if routing.leaveEventForText {
            if let token = ShortcutKey.token(for: Int(event.keyCode)) {
                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                let input = ShortcutInput(
                    token: token,
                    command: flags.contains(.command),
                    shift: flags.contains(.shift),
                    option: flags.contains(.option),
                    control: flags.contains(.control)
                )
                if let shortcut = ShortcutCatalog.match(input), !shortcut.command {
                    uiLog.debug("shortcut \(shortcut.id, privacy: .public) ignored, text input")
                }
            }
            return false
        }
        PlayerModel.shared.poke()
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard let token = ShortcutKey.token(for: Int(event.keyCode)) else { return false }
        let input = ShortcutInput(
            token: token,
            command: flags.contains(.command),
            shift: flags.contains(.shift),
            option: flags.contains(.option),
            control: flags.contains(.control)
        )
        guard let shortcut = ShortcutCatalog.match(input) else { return false }
        let model = PlayerModel.shared
        if shortcut.id == "leaveFullScreen", !model.fullscreen { return false }
        uiLog.debug("shortcut \(shortcut.id, privacy: .public)")
        model.performShortcut(shortcut.id)
        return true
    }

    private static func isText(_ responder: NSResponder?) -> Bool {
        responder is NSText || responder is NSTextField
    }
}
