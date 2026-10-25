import AppKit
import MeowxCore
import os

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private static let uiLog = Logger(subsystem: "com.cappy7.meowx", category: "ui")
    private let recentMenu = NSMenu()

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
        DispatchQueue.main.async { [weak self] in
            self?.installRecentMenu()
        }
    }

    private func installRecentMenu() {
        guard let file = NSApp.mainMenu?.item(withTitle: "File")?.submenu else {
            Self.uiLog.error("File menu missing, Open Recent was not added")
            return
        }
        if file.items.contains(where: { $0.submenu === recentMenu }) { return }
        recentMenu.delegate = self
        let item = NSMenuItem(title: "Open Recent", action: nil, keyEquivalent: "")
        item.submenu = recentMenu
        file.addItem(.separator())
        file.addItem(item)
        Self.uiLog.info("Open Recent added to the File menu")
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === recentMenu else { return }
        menu.removeAllItems()
        let urls = NSDocumentController.shared.recentDocumentURLs
        if urls.isEmpty {
            let none = NSMenuItem(title: "None", action: nil, keyEquivalent: "")
            none.isEnabled = false
            menu.addItem(none)
        } else {
            for url in urls.prefix(10) {
                let item = NSMenuItem(title: url.lastPathComponent, action: #selector(openDockRecent(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = url
                menu.addItem(item)
            }
        }
        menu.addItem(.separator())
        let clear = NSMenuItem(title: "Clear Menu", action: #selector(clearDockRecent(_:)), keyEquivalent: "")
        clear.target = self
        clear.isEnabled = !urls.isEmpty
        menu.addItem(clear)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        PlayerModel.shared.start()
        PlayerModel.shared.presentWindow()
        PlayerModel.shared.add(urls: urls, playNow: true)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        PlayerModel.shared.prepareToQuit()
        return .terminateNow
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        PlayerModel.shared.settings.quitWhenWindowCloses
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            PlayerModel.shared.presentWindow()
        }
        return true
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        let urls = NSDocumentController.shared.recentDocumentURLs
        if urls.isEmpty {
            let none = NSMenuItem(title: "No Recent Items", action: nil, keyEquivalent: "")
            none.isEnabled = false
            menu.addItem(none)
        } else {
            for url in urls.prefix(10) {
                let item = NSMenuItem(title: url.lastPathComponent, action: #selector(openDockRecent(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = url
                menu.addItem(item)
            }
            menu.addItem(.separator())
            let clear = NSMenuItem(title: "Clear Menu", action: #selector(clearDockRecent(_:)), keyEquivalent: "")
            clear.target = self
            menu.addItem(clear)
        }
        return menu
    }

    @objc private func openDockRecent(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        PlayerModel.shared.presentWindow()
        PlayerModel.shared.add(urls: [url], playNow: true)
    }

    @objc private func clearDockRecent(_ sender: NSMenuItem) {
        NSDocumentController.shared.clearRecentDocuments(nil)
        PlayerModel.shared.recentRevision += 1
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
