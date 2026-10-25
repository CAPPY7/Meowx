import AppKit
import MeowxCore
import os

final class ThumbnailService {
    static let shared = ThumbnailService()
    private static let log = Logger(subsystem: "com.cappy7.meowx", category: "ui")

    private struct Job {
        var path: String
        var time: Double
        var hover: Bool
        var cacheKey: String
        var completion: (NSImage?) -> Void
    }

    private let queue = DispatchQueue(label: "com.cappy7.meowx.thumbnails")
    private let lock = NSLock()
    private var jobs: [Job] = []
    private var memory: [String: NSImage] = [:]
    private var frames: [String: NSImage] = [:]
    private var pumping = false
    private var unavailable = false
    private var mpv: OpaquePointer?
    private var render: OpaquePointer?
    private var glContext: UnsafeMutableRawPointer?
    private var fbo: UInt32 = 0
    private var texture: UInt32 = 0
    private var loadedPath: String?
    private let width = 320
    private let height = 180

    func request(path: String, time: Double, completion: @escaping (NSImage?) -> Void) {
        if path.contains("://") {
            Self.log.info("thumbnail skipped for a network address")
            DispatchQueue.main.async { completion(nil) }
            return
        }
        let cacheKey = ThumbnailCache.frameKey(path: path, time: time)
        lock.lock()
        if let image = frames[cacheKey] {
            lock.unlock()
            DispatchQueue.main.async { completion(image) }
            return
        }
        if unavailable {
            lock.unlock()
            DispatchQueue.main.async { completion(nil) }
            return
        }
        jobs.removeAll { $0.hover }
        jobs.insert(Job(path: path, time: time, hover: true, cacheKey: cacheKey, completion: completion), at: 0)
        let start = !pumping
        if start { pumping = true }
        lock.unlock()
        guard start else { return }
        queue.async { [weak self] in self?.pump() }
    }

    /// First frame-ish poster for a local file. The PNG is reused from Application Support.
    func cachedPoster(for url: URL, completion: @escaping (NSImage?) -> Void) {
        guard url.isFileURL else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        let key = ThumbnailCache.key(path: url.path, fileSize: size)
        lock.lock()
        if let image = memory[key] {
            lock.unlock()
            DispatchQueue.main.async { completion(image) }
            return
        }
        lock.unlock()
        let file = Self.cacheDirectory.appendingPathComponent(key + ".png")
        if let image = NSImage(contentsOf: file) {
            lock.lock()
            memory[key] = image
            lock.unlock()
            DispatchQueue.main.async { completion(image) }
            return
        }
        requestPoster(path: url.path, time: 5) { [weak self] image in
            guard let self else {
                completion(nil)
                return
            }
            if let image {
                Self.write(image, to: file)
                self.lock.lock()
                self.memory[key] = image
                self.lock.unlock()
            }
            completion(image)
        }
    }

    private func requestPoster(path: String, time: Double, completion: @escaping (NSImage?) -> Void) {
        lock.lock()
        if unavailable {
            lock.unlock()
            DispatchQueue.main.async { completion(nil) }
            return
        }
        jobs.append(Job(path: path, time: time, hover: false, cacheKey: ThumbnailCache.frameKey(path: path, time: time), completion: completion))
        let start = !pumping
        if start { pumping = true }
        lock.unlock()
        guard start else { return }
        queue.async { [weak self] in self?.pump() }
    }

    private func pump() {
        if !ensureEngine() {
            lock.lock()
            unavailable = true
            pumping = false
            let dropped = jobs
            jobs.removeAll()
            lock.unlock()
            if !dropped.isEmpty {
                DispatchQueue.main.async {
                    dropped.forEach { $0.completion(nil) }
                }
            }
            return
        }
        while true {
            lock.lock()
            let job = jobs.isEmpty ? nil : jobs.removeFirst()
            if job == nil {
                pumping = false
                lock.unlock()
                return
            }
            lock.unlock()
            guard let job else { return }
            let stale = job.hover && newerHoverWaiting()
            let data = stale ? nil : renderThumbnail(path: job.path, time: job.time)
            if mpv == nil {
                lock.lock()
                unavailable = true
                lock.unlock()
            }
            let width = self.width
            let height = self.height
            let cacheKey = job.cacheKey
            DispatchQueue.main.async { [weak self] in
                let image = data.flatMap { Self.image(from: $0, width: width, height: height) }
                if let self, let image {
                    self.lock.lock()
                    self.frames[cacheKey] = image
                    if self.frames.count > 80 { self.frames.removeAll() }
                    self.lock.unlock()
                }
                job.completion(image)
            }
        }
    }

    private func newerHoverWaiting() -> Bool {
        lock.lock()
        let waiting = jobs.contains { $0.hover }
        lock.unlock()
        return waiting
    }

    private func ensureEngine() -> Bool {
        if mpv != nil && render != nil { return true }
        meowx_gl_lock()
        defer { meowx_gl_unlock() }
        guard let context = meowx_gl_offscreen_context() else { return false }
        glContext = context
        meowx_cgl_set_current(context)
        var fbo: UInt32 = 0
        var texture: UInt32 = 0
        guard meowx_gl_make_fbo(Int32(width), Int32(height), &fbo, &texture) == 0 else { return false }
        self.fbo = fbo
        self.texture = texture
        guard let mpv = mpv_create() else { return false }
        mpv_set_option_string(mpv, "vo", "libmpv")
        mpv_set_option_string(mpv, "hwdec", "auto")
        mpv_set_option_string(mpv, "vd-lavc-threads", "2")
        mpv_set_option_string(mpv, "ao", "null")
        mpv_set_option_string(mpv, "audio", "no")
        mpv_set_option_string(mpv, "mute", "yes")
        mpv_set_option_string(mpv, "pause", "yes")
        mpv_set_option_string(mpv, "idle", "yes")
        mpv_set_option_string(mpv, "keep-open", "yes")
        mpv_set_option_string(mpv, "hr-seek", "no")
        mpv_set_option_string(mpv, "osc", "no")
        mpv_set_option_string(mpv, "ytdl", "no")
        mpv_set_option_string(mpv, "config", "no")
        mpv_set_option_string(mpv, "input-default-bindings", "no")
        guard mpv_initialize(mpv) >= 0 else {
            mpv_terminate_destroy(mpv)
            return false
        }
        var render: OpaquePointer?
        guard meowx_gl_create_render(&render, mpv) >= 0, let render else {
            mpv_terminate_destroy(mpv)
            return false
        }
        self.mpv = mpv
        self.render = render
        return true
    }

    func shutdown() {
        lock.lock()
        let dropped = jobs
        jobs.removeAll()
        pumping = false
        unavailable = true
        lock.unlock()
        DispatchQueue.main.async {
            dropped.forEach { $0.completion(nil) }
        }
        queue.sync { teardown() }
        Self.log.info("thumbnail engine shut down")
    }

    private func teardown() {
        meowx_gl_lock()
        defer { meowx_gl_unlock() }
        if let render {
            mpv_render_context_set_update_callback(render, { _ in }, nil)
            mpv_render_context_free(render)
            self.render = nil
        }
        if let mpv {
            mpv_terminate_destroy(mpv)
            self.mpv = nil
        }
        if glContext != nil {
            meowx_cgl_clear_current()
            glContext = nil
        }
        loadedPath = nil
    }

    private func renderThumbnail(path: String, time: Double) -> Data? {
        guard let mpv, let render, let glContext else { return nil }
        if newerHoverWaiting() { return nil }
        if loadedPath != path {
            let joined = ["loadfile", path, "replace"].joined(separator: "\u{1f}")
            guard meowx_command_sep(mpv, joined) >= 0, wait(mpv, for: MPV_EVENT_FILE_LOADED, timeout: 4) else {
                return nil
            }
            loadedPath = path
        }
        if newerHoverWaiting() { return nil }
        let seek = ["seek", String(format: "%.3f", max(0, time)), "absolute+keyframes"].joined(separator: "\u{1f}")
        _ = meowx_command_sep(mpv, seek)
        _ = waitForSeek(mpv, timeout: 0.8)
        if newerHoverWaiting() { return nil }
        meowx_gl_lock()
        defer { meowx_gl_unlock() }
        meowx_cgl_set_current(glContext)
        _ = mpv_render_context_update(render)
        meowx_gl_render_fbo(render, fbo, Int32(width), Int32(height), 0)
        mpv_render_context_report_swap(render)
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        bytes.withUnsafeMutableBytes { raw in
            guard let base = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            meowx_gl_read_rgba_flipped(fbo, Int32(width), Int32(height), base)
        }
        return Data(bytes)
    }

    private func wait(_ mpv: OpaquePointer, for kind: mpv_event_id, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            guard let event = mpv_wait_event(mpv, 0.05) else { continue }
            let id = event.pointee.event_id
            if id == kind { return true }
            if id == MPV_EVENT_END_FILE { return false }
        }
        return false
    }

    private func waitForSeek(_ mpv: OpaquePointer, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            guard let event = mpv_wait_event(mpv, 0.05) else { continue }
            let id = event.pointee.event_id
            if id == MPV_EVENT_SEEK || id == MPV_EVENT_PLAYBACK_RESTART || id == MPV_EVENT_FILE_LOADED {
                return true
            }
            if id == MPV_EVENT_END_FILE { return false }
        }
        return false
    }

    private static func image(from data: Data, width: Int, height: Int) -> NSImage? {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: width * 4,
            bitsPerPixel: 32
        ), let plane = rep.bitmapData else { return nil }
        data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            plane.assign(from: base.assumingMemoryBound(to: UInt8.self), count: width * height * 4)
        }
        var proposed = NSRect(x: 0, y: 0, width: width, height: height)
        guard let cg = rep.cgImage(forProposedRect: &proposed, context: nil, hints: nil) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: width, height: height))
    }

    private static var cacheDirectory: URL {
        AppPaths.support.appendingPathComponent("Thumbnails", isDirectory: true)
    }

    private static func write(_ image: NSImage, to url: URL) {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? png.write(to: url, options: .atomic)
    }
}
