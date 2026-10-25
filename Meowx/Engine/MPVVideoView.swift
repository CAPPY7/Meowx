import AppKit
import MeowxCore
import os

final class FrameFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = true

    func set() {
        lock.lock()
        value = true
        lock.unlock()
    }

    func peek() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func take() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let current = value
        value = false
        return current
    }
}

final class MPVGLLayer: CAOpenGLLayer {
    let frames = FrameFlag()
    weak var videoView: MPVVideoView?

    override init() {
        super.init()
        isAsynchronous = false
        needsDisplayOnBoundsChange = true
        isOpaque = true
        backgroundColor = NSColor.black.cgColor
        contentsScale = 2
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func copyCGLPixelFormat(forDisplayMask mask: UInt32) -> CGLPixelFormatObj {
        if let raw = meowx_gl_pixel_format_for_display(mask) {
            return unsafeBitCast(raw, to: CGLPixelFormatObj.self)
        }
        return super.copyCGLPixelFormat(forDisplayMask: mask)
    }

    override func releaseCGLPixelFormat(_ pf: CGLPixelFormatObj) {
        meowx_cgl_release_pixel_format(UnsafeMutableRawPointer(pf))
    }

    override func canDraw(
        inCGLContext ctx: CGLContextObj,
        pixelFormat pf: CGLPixelFormatObj,
        forLayerTime t: CFTimeInterval,
        displayTime ts: UnsafePointer<CVTimeStamp>?
    ) -> Bool {
        frames.peek()
    }

    override func draw(
        inCGLContext ctx: CGLContextObj,
        pixelFormat pf: CGLPixelFormatObj,
        forLayerTime t: CFTimeInterval,
        displayTime ts: UnsafePointer<CVTimeStamp>?
    ) {
        _ = frames.take()
        let scale = max(contentsScale, 1)
        let width = Int((bounds.width * scale).rounded())
        let height = Int((bounds.height * scale).rounded())
        videoView?.controller?.drawFrame(width: width, height: height)
    }
}

final class MPVVideoView: NSView, NSTouchBarDelegate {
    let glLayer = MPVGLLayer()
    weak var controller: MPVController?
    private var displayLink: CADisplayLink?
    private var playItem: NSButtonTouchBarItem?
    private var click = PendingClick()
    private var clickWork: DispatchWorkItem?
    private var downPoint: NSPoint?
    private let uiLog = Logger(subsystem: "com.cappy7.meowx", category: "ui")
    private let playID = NSTouchBarItem.Identifier("com.cappy7.meowx.play")
    private let previousID = NSTouchBarItem.Identifier("com.cappy7.meowx.previous")
    private let nextID = NSTouchBarItem.Identifier("com.cappy7.meowx.next")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        glLayer.videoView = self
        layerContentsRedrawPolicy = .duringViewResize
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func makeBackingLayer() -> CALayer {
        glLayer
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        glLayer.contentsScale = window?.backingScaleFactor ?? 2
        startDisplayLink()
        window?.touchBar = makeTouchBar()
        if window == nil {
            displayLink?.invalidate()
            displayLink = nil
        }
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        glLayer.contentsScale = window?.backingScaleFactor ?? 2
        markFramePending()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func menu(for event: NSEvent) -> NSMenu? {
        uiLog.info("context menu requested")
        PlayerModel.shared.poke()
        return VideoContextMenu.make()
    }

    override func mouseDown(with event: NSEvent) {
        downPoint = event.locationInWindow
        PlayerModel.shared.poke()
        if event.clickCount >= 2 {
            clickWork?.cancel()
            let local = convert(event.locationInWindow, from: nil)
            let zone = PictureZone.at(x: local.x, width: bounds.width)
            let action = click.secondClick(zone: zone, sideSeekEnabled: PlayerModel.shared.settings.doubleClickSidesSeek)
            switch action {
            case .toggleFullScreen:
                uiLog.info("double click full screen")
                PlayerModel.shared.toggleFullscreen()
            case .seekBackward:
                uiLog.info("double click back 10")
                PlayerModel.shared.seek(by: -PlayerModel.shared.settings.seekMedium)
            case .seekForward:
                uiLog.info("double click forward 10")
                PlayerModel.shared.seek(by: PlayerModel.shared.settings.seekMedium)
            case .togglePause, .none:
                break
            }
            return
        }
        click.firstClick(pauseEnabled: PlayerModel.shared.settings.clickToPause)
        clickWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if self.click.fireIfStillPending() == .togglePause {
                self.uiLog.info("single click pause")
                PlayerModel.shared.togglePause()
            }
        }
        clickWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let downPoint else { return }
        let point = event.locationInWindow
        let moved = hypot(point.x - downPoint.x, point.y - downPoint.y)
        guard moved > 4 else { return }
        clickWork?.cancel()
        click.dragged()
        guard !PlayerModel.shared.fullscreen, let window else { return }
        uiLog.info("drag window from video")
        window.performDrag(with: event)
    }

    override func otherMouseDown(with event: NSEvent) {
        guard event.buttonNumber == 2 else { return }
        uiLog.info("middle click mute")
        PlayerModel.shared.toggleMute()
    }

    override func scrollWheel(with event: NSEvent) {
        let momentum = event.momentumPhase != []
        PlayerModel.shared.applyPointerScroll(
            deltaX: event.scrollingDeltaX,
            deltaY: event.scrollingDeltaY,
            precise: event.hasPreciseScrollingDeltas,
            momentum: momentum
        )
    }

    override func layout() {
        super.layout()
        markFramePending()
    }

    func markFramePending() {
        glLayer.frames.set()
    }

    func updateTouchBar() {
        let paused = PlayerModel.shared.paused || PlayerModel.shared.playlist.current == nil
        playItem?.image = NSImage(systemSymbolName: paused ? "play.fill" : "pause.fill", accessibilityDescription: paused ? "Play" : "Pause")
    }

    private func startDisplayLink() {
        guard displayLink == nil, window != nil else { return }
        let link = displayLink(target: self, selector: #selector(displayTick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func displayTick() {
        if glLayer.frames.peek() {
            glLayer.setNeedsDisplay()
        }
    }

    override func makeTouchBar() -> NSTouchBar? {
        let bar = NSTouchBar()
        bar.delegate = self
        bar.defaultItemIdentifiers = [previousID, playID, nextID]
        return bar
    }

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {
        case previousID:
            return buttonItem(identifier, symbol: "backward.fill", action: #selector(previousPressed))
        case nextID:
            return buttonItem(identifier, symbol: "forward.fill", action: #selector(nextPressed))
        case playID:
            let item = buttonItem(identifier, symbol: "play.fill", action: #selector(playPressed))
            playItem = item as? NSButtonTouchBarItem
            updateTouchBar()
            return item
        default:
            return nil
        }
    }

    private func buttonItem(_ identifier: NSTouchBarItem.Identifier, symbol: String, action: Selector) -> NSTouchBarItem {
        let item = NSButtonTouchBarItem(identifier: identifier)
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        item.target = self
        item.action = action
        item.bezelColor = .controlAccentColor
        return item
    }

    @objc private func playPressed() { PlayerModel.shared.togglePause() }
    @objc private func previousPressed() { PlayerModel.shared.previous() }
    @objc private func nextPressed() { PlayerModel.shared.next() }
}
