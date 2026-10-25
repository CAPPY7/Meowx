import AppKit
import MeowxCore
import os
import SwiftUI

/// Makes the video run under a transparent title bar and fades the traffic lights with playback chrome.
struct WindowChrome: NSViewRepresentable {
    var shown: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        view.isHidden = true
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.sync(nsView, shown: shown)
    }

    final class Coordinator: NSObject {
        private let proxy = WindowDelegateProxy()
        private var shown = true
        private weak var window: NSWindow?
        private let log = Logger(subsystem: "com.cappy7.meowx", category: "ui")

        func sync(_ view: NSView, shown: Bool) {
            guard let window = view.window else { return }
            if self.window !== window {
                self.window = window
                configure(window)
            }
            claim(window)
            window.toolbar?.isVisible = false
            measureTraffic(window)
            guard self.shown != shown else { return }
            self.shown = shown
            log.info("traffic lights \(shown ? "show" : "hide", privacy: .public)")
            fadeButtons(window, shown: shown)
        }

        private func configure(_ window: NSWindow) {
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.titlebarSeparatorStyle = .none
            window.styleMask.insert(.fullSizeContentView)
            window.acceptsMouseMovedEvents = true
            window.toolbar?.isVisible = false
            PlayerModel.shared.attachContentWindow(window)
            NotificationCenter.default.addObserver(self, selector: #selector(windowChanged(_:)), name: NSWindow.didResizeNotification, object: window)
            NotificationCenter.default.addObserver(self, selector: #selector(windowChanged(_:)), name: NSWindow.didEnterFullScreenNotification, object: window)
            NotificationCenter.default.addObserver(self, selector: #selector(windowChanged(_:)), name: NSWindow.didExitFullScreenNotification, object: window)
            measureTraffic(window)
        }

        @objc private func windowChanged(_ note: Notification) {
            guard let window = note.object as? NSWindow else { return }
            measureTraffic(window)
        }

        private func measureTraffic(_ window: NSWindow) {
            let kinds: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
            let maxX = kinds.compactMap { window.standardWindowButton($0) }.map { button in
                button.convert(button.bounds, to: nil).maxX
            }.max() ?? 0
            PlayerModel.shared.noteTrafficInset(buttonMaxX: maxX, fullscreen: window.styleMask.contains(.fullScreen))
        }

        private func claim(_ window: NSWindow) {
            if window.delegate === proxy { return }
            proxy.forwarded = window.delegate
            window.delegate = proxy
        }

        private func fadeButtons(_ window: NSWindow, shown: Bool) {
            let alpha: CGFloat = shown ? 1 : 0
            NSAnimationContext.runAnimationGroup { context in
                let reduce = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
                context.duration = Theme.appKitFade(reduceMotion: reduce)
                let kinds: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
                for kind in kinds {
                    window.standardWindowButton(kind)?.animator().alphaValue = alpha
                }
                if let box = window.standardWindowButton(.closeButton)?.superview, box.bounds.height < 80 {
                    box.animator().alphaValue = alpha
                }
            }
        }
    }
}

/// Forwards every window-delegate call except full-screen presentation, which must auto-hide system chrome.
final class WindowDelegateProxy: NSObject, NSWindowDelegate {
    weak var forwarded: NSWindowDelegate?

    func window(
        _ window: NSWindow,
        willUseFullScreenPresentationOptions proposedOptions: NSApplication.PresentationOptions
    ) -> NSApplication.PresentationOptions {
        [.fullScreen, .autoHideToolbar, .autoHideMenuBar, .autoHideDock]
    }

    func windowShouldClose(_ window: NSWindow) -> Bool {
        PlayerModel.shared.allowWindowClose()
    }

    override func responds(to selector: Selector!) -> Bool {
        if selector == #selector(window(_:willUseFullScreenPresentationOptions:)) { return true }
        if selector == #selector(windowShouldClose(_:)) { return true }
        if let forwarded, forwarded.responds(to: selector) { return true }
        return super.responds(to: selector)
    }

    override func forwardingTarget(for selector: Selector!) -> Any? {
        if selector == #selector(window(_:willUseFullScreenPresentationOptions:)) { return nil }
        if selector == #selector(windowShouldClose(_:)) { return nil }
        return forwarded
    }
}
