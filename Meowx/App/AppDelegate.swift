import AppKit
import MeowxCore
import os

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private static let uiLog = Logger(subsystem: "com.cappy7.meowx", category: "ui")
    private let recentMenu = NSMenu()
    private let chapterMenu = NSMenu()

    func applicationDidFinishLaunching(_ notification: Notification) {
        PlayerModel.shared.start()
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            Self.handle(event) ? nil : event
        }
        NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .scrollWheel]) { event in
            guard event.window != nil else { return event }
            if event.type == .scrollWheel {
                PlayerModel.shared.poke()
            } else {
                PlayerModel.shared.notePointer(
                    x: event.locationInWindow.x,
                    y: event.locationInWindow.y,
                    dragged: event.type != .mouseMoved
                )
            }
            return event
        }
        DispatchQueue.main.async { [weak self] in
            self?.installRecentMenu()
            self?.installChapterMenu()
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

    private func installChapterMenu() {
        guard let playback = NSApp.mainMenu?.item(withTitle: "Playback")?.submenu else {
            Self.uiLog.error("Playback menu missing, Chapters was not added")
            return
        }
        if playback.items.contains(where: { $0.submenu === chapterMenu }) { return }
        chapterMenu.delegate = self
        let item = NSMenuItem(title: "Chapters", action: nil, keyEquivalent: "")
        item.submenu = chapterMenu
        if let end = playback.items.firstIndex(where: { $0.title.hasPrefix("Go to End") }) {
            playback.insertItem(item, at: end + 1)
        } else {
            playback.addItem(item)
        }
        Self.uiLog.info("Chapters menu added")
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu === chapterMenu {
            refillChapters(menu)
            return
        }
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

    private func refillChapters(_ menu: NSMenu) {
        menu.removeAllItems()
        let model = PlayerModel.shared
        let previous = NSMenuItem(title: "Previous", action: #selector(chapterStep(_:)), keyEquivalent: "")
        previous.target = self
        previous.tag = -1
        menu.addItem(previous)
        let next = NSMenuItem(title: "Next", action: #selector(chapterStep(_:)), keyEquivalent: "")
        next.target = self
        next.tag = 1
        menu.addItem(next)
        menu.addItem(.separator())
        if model.chapters.isEmpty {
            let none = NSMenuItem(title: "No chapters", action: nil, keyEquivalent: "")
            none.isEnabled = false
            menu.addItem(none)
            return
        }
        for chapter in model.chapters {
            let name = ChapterNav.displayTitle(index: chapter.index, title: chapter.title)
            let item = NSMenuItem(
                title: "\(name)  \(TimeFormat.string(chapter.time))",
                action: #selector(chapterPick(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.state = chapter.index == model.chapterIndex ? .on : .off
            item.representedObject = NSNumber(value: chapter.index)
            menu.addItem(item)
        }
    }

    @objc private func chapterStep(_ sender: NSMenuItem) {
        PlayerModel.shared.stepChapter(sender.tag)
    }

    @objc private func chapterPick(_ sender: NSMenuItem) {
        guard let index = (sender.representedObject as? NSNumber)?.intValue else { return }
        PlayerModel.shared.seekChapter(index)
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
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if PlayerModel.shared.shortcutCaptureID != nil, let token = ShortcutKey.token(for: Int(event.keyCode)) {
            PlayerModel.shared.takeShortcut(ShortcutInput(
                token: token,
                command: flags.contains(.command),
                shift: flags.contains(.shift),
                option: flags.contains(.option),
                control: flags.contains(.control)
            ))
            return true
        }
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
                if let shortcut = ShortcutMap.match(input, overrides: PlayerModel.shared.settings.shortcutOverrides), !shortcut.command {
                    uiLog.debug("shortcut \(shortcut.id, privacy: .public) ignored, text input")
                }
            }
            return false
        }
        PlayerModel.shared.poke()
        guard let token = ShortcutKey.token(for: Int(event.keyCode)) else { return false }
        let input = ShortcutInput(
            token: token,
            command: flags.contains(.command),
            shift: flags.contains(.shift),
            option: flags.contains(.option),
            control: flags.contains(.control)
        )
        let model = PlayerModel.shared
        guard let shortcut = ShortcutMap.match(input, overrides: model.settings.shortcutOverrides) else { return false }
        if shortcut.id == "leaveFullScreen" {
            if model.playlistShown {
                model.setPlaylistOpen(false)
                return true
            }
            if !model.fullscreen { return false }
        }
        uiLog.debug("shortcut \(shortcut.id, privacy: .public)")
        model.performShortcut(shortcut.id)
        return true
    }

    private static func isText(_ responder: NSResponder?) -> Bool {
        responder is NSText || responder is NSTextField
    }
}
