import Foundation
import MeowxCore
import os

struct MediaTrack: Identifiable, Equatable {
    let id: Int
    var kind: String
    var title: String
    var language: String
    var codec: String
    var channels: String
    var albumArt: Bool
    var isDefault: Bool
    var isExternal: Bool
    var isForced: Bool

    var label: String {
        TrackLabel.text(
            kind: kind,
            id: id,
            language: language,
            title: title,
            codec: codec,
            channels: channels,
            isDefault: isDefault,
            isExternal: isExternal,
            isForced: isForced,
            albumArt: albumArt
        )
    }
}

struct EngineSnapshot {
    var position: Double = 0
    var duration: Double = 0
    var paused: Bool = true
    var volume: Double = 100
    var muted: Bool = false
    var speed: Double = 1
    var buffering: Bool = false
    var cacheSeconds: Double = 0
    var hwdec: String = ""
    var width: Int = 0
    var height: Int = 0
    var fps: Double = 0
    var droppedFrames: Int = 0
    var videoCodec: String = ""
    var audioCodec: String = ""
    var videoBitrate: Double = 0
    var gamma: String = ""
    var primaries: String = ""
}

enum EngineEnd: Equatable {
    case eof
    case stop
    case error(String)
}

protocol EngineDelegate: AnyObject {
    func engineFileLoaded()
    func engineEnded(_ end: EngineEnd)
    func enginePauseChanged(_ paused: Bool)
    func engineBufferingChanged(_ buffering: Bool)
    func engineTracksChanged()
}

final class MPVController {
    weak var delegate: EngineDelegate?
    weak var videoView: MPVVideoView?

    private let handle: OpaquePointer
    private var renderContext: OpaquePointer?
    private var glContext: UnsafeMutableRawPointer?
    private let log = Logger(subsystem: "com.cappy7.meowx", category: "mpv")
    private var started = false

    init?(settings: PlayerSettings, ytdlpPath: String?) {
        guard let handle = mpv_create() else { return nil }
        self.handle = handle
        option("config", "no")
        option("terminal", "no")
        option("vo", "libmpv")
        option("idle", "yes")
        option("keep-open", "yes")
        option("force-window", "no")
        option("osc", "no")
        option("osd-level", "1")
        option("osd-on-seek", "no")
        option("input-default-bindings", "no")
        option("input-vo-keyboard", "no")
        option("input-media-keys", "no")
        option("cursor-autohide", "no")
        option("keepaspect", "yes")
        option("hr-seek", "yes")
        option("stop-screensaver", "yes")
        option("audio-pitch-correction", "yes")
        option("volume-max", "200")
        option("cache", "yes")
        option("cache-pause", "no")
        option("demuxer-max-bytes", "\(settings.cacheMegabytes)MiB")
        option("demuxer-max-back-bytes", "\(settings.cacheBackMegabytes)MiB")
        option("demuxer-readahead-secs", "60")
        option("sub-auto", "fuzzy")
        option("audio-file-auto", "fuzzy")
        option("hwdec", settings.hardwareDecoding ? "videotoolbox" : "no")
        option("gpu-hwdec-interop", "auto")
        option("target-colorspace-hint", "yes")
        option("tone-mapping", "auto")
        option("msg-level", "all=warn")
        if !settings.subtitleLanguage.isEmpty { option("slang", settings.subtitleLanguage) }
        if !settings.audioLanguage.isEmpty { option("alang", settings.audioLanguage) }
        if let ytdlpPath {
            option("ytdl", "yes")
            option("script-opts", "ytdl_hook-ytdl_path=\(ytdlpPath)")
        } else {
            option("ytdl", "no")
        }
        if let script = Bundle.main.resourceURL?.appendingPathComponent("mpv/scripts/ytdl_hook.lua"),
           FileManager.default.fileExists(atPath: script.path) {
            option("scripts", script.path)
        }
        let code = mpv_initialize(handle)
        guard code >= 0 else {
            log.error("mpv_initialize failed: \(self.errorText(code), privacy: .public)")
            mpv_terminate_destroy(handle)
            return nil
        }
        started = true
        mpv_request_log_messages(handle, "warn")
        observe("pause", MPV_FORMAT_FLAG)
        observe("paused-for-cache", MPV_FORMAT_FLAG)
        observe("eof-reached", MPV_FORMAT_FLAG)
        observe("track-list", MPV_FORMAT_NONE)
        apply(settings)
    }

    func installWakeup() {
        guard started else { return }
        let opaque = Unmanaged.passUnretained(self).toOpaque()
        mpv_set_wakeup_callback(handle, { raw in
            guard let raw else { return }
            let controller = Unmanaged<MPVController>.fromOpaque(raw).takeUnretainedValue()
            DispatchQueue.main.async { [weak controller] in
                controller?.drainEvents()
            }
        }, opaque)
    }

    deinit {
        shutdown()
    }

    func shutdown() {
        guard started else { return }
        started = false
        mpv_set_wakeup_callback(handle, nil, nil)
        meowx_gl_lock()
        if let glContext {
            meowx_cgl_set_current(glContext)
        }
        if let renderContext {
            mpv_render_context_set_update_callback(renderContext, { _ in }, nil)
            mpv_render_context_free(renderContext)
            self.renderContext = nil
        }
        meowx_cgl_clear_current()
        meowx_gl_unlock()
        mpv_terminate_destroy(handle)
    }

    func drawFrame(width: Int, height: Int) {
        guard started, width > 1, height > 1 else { return }
        meowx_gl_lock()
        defer { meowx_gl_unlock() }
        if let glContext {
            meowx_cgl_set_current(glContext)
        } else {
            glContext = meowx_cgl_get_current()
        }
        if renderContext == nil {
            var created: OpaquePointer?
            let code = meowx_gl_create_render(&created, handle)
            guard code >= 0, let created else {
                log.error("OpenGL render context failed: \(self.errorText(code), privacy: .public)")
                return
            }
            renderContext = created
            if let videoView {
                let raw = Unmanaged.passUnretained(videoView).toOpaque()
                mpv_render_context_set_update_callback(created, { opaque in
                    guard let opaque else { return }
                    let view = Unmanaged<MPVVideoView>.fromOpaque(opaque).takeUnretainedValue()
                    view.markFramePending()
                }, raw)
            }
        }
        guard let renderContext else { return }
        _ = mpv_render_context_update(renderContext)
        _ = meowx_gl_render(renderContext, Int32(width), Int32(height), 1, 1)
        mpv_render_context_report_swap(renderContext)
    }

    @discardableResult
    func command(_ args: [String]) -> Int32 {
        guard started, !args.isEmpty else { return -1 }
        let joined = args.joined(separator: "\u{1f}")
        let code = meowx_command_sep(handle, joined)
        if code < 0 {
            log.error("command \(args[0], privacy: .public) failed: \(self.errorText(code), privacy: .public)")
        }
        return code
    }

    func load(_ url: URL) {
        let path = url.isFileURL ? url.path : url.absoluteString
        command(["loadfile", path, "replace"])
    }

    func setPaused(_ paused: Bool) {
        setString("pause", paused ? "yes" : "no")
    }

    func seekAbsolute(_ seconds: Double, exact: Bool) {
        command(["seek", String(format: "%.3f", max(0, seconds)), exact ? "absolute+exact" : "absolute"])
    }

    func seekRelative(_ seconds: Double) {
        command(["seek", String(format: "%.3f", seconds), "relative+exact"])
    }

    func frameStep(backward: Bool) {
        command([backward ? "frame-back-step" : "frame-step"])
    }

    func setSpeed(_ speed: Double) {
        setDouble("speed", min(4, max(0.25, speed)))
    }

    func setVolume(_ volume: Double) {
        setDouble("volume", min(200, max(0, volume)))
    }

    func setMuted(_ muted: Bool) {
        setString("mute", muted ? "yes" : "no")
    }

    func cycle(_ name: String, backward: Bool = false) {
        if backward {
            command(["cycle", name, "down"])
        } else {
            command(["cycle", name])
        }
    }

    func selectTrack(_ property: String, id: Int) {
        setString(property, id <= 0 ? "no" : String(id))
    }

    @discardableResult
    func nudge(_ property: String, by delta: Double) -> Double {
        let updated = (doubleProp(property) ?? 0) + delta
        setDouble(property, updated)
        return updated
    }

    func addSubtitle(path: String) {
        command(["sub-add", path, "select"])
    }

    func chapters() -> [MediaChapter] {
        let count = min(500, max(0, intProp("chapter-list/count") ?? 0))
        guard count > 0 else { return [] }
        var list: [MediaChapter] = []
        list.reserveCapacity(count)
        for index in 0..<count {
            let prefix = "chapter-list/\(index)/"
            list.append(MediaChapter(
                index: index,
                title: stringProp(prefix + "title") ?? "",
                time: doubleProp(prefix + "time") ?? 0
            ))
        }
        return list
    }

    func setVideoFilter(_ filter: String) {
        if filter.isEmpty {
            command(["vf", "clr"])
        } else {
            command(["vf", "set", filter])
        }
    }

    @discardableResult
    func screenshot(to url: URL, format: String, subtitles: Bool = false) -> Bool {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        setString("screenshot-format", format)
        let flag = subtitles ? "subtitles" : "video"
        return command(["screenshot-to-file", url.path, flag]) >= 0
    }

    @discardableResult
    func setAudioFilter(_ filter: String) -> Bool {
        if filter.isEmpty { return command(["af", "clr"]) >= 0 }
        return command(["af", "set", filter]) >= 0
    }

    func audioOutputs() -> [(id: String, name: String)] {
        guard started else { return [] }
        var node = mpv_node()
        guard mpv_get_property(handle, "audio-device-list", MPV_FORMAT_NODE, &node) >= 0 else { return [] }
        defer { mpv_free_node_contents(&node) }
        guard node.format == MPV_FORMAT_NODE_ARRAY, let list = node.u.list else { return [] }
        var result: [(id: String, name: String)] = []
        for index in 0..<Int(list.pointee.num) {
            let item = list.pointee.values[index]
            guard item.format == MPV_FORMAT_NODE_MAP, let map = item.u.list else { continue }
            var id = ""
            var name = ""
            for field in 0..<Int(map.pointee.num) {
                guard let keyPtr = map.pointee.keys?[field] else { continue }
                let key = String(cString: keyPtr)
                let value = map.pointee.values[field]
                guard value.format == MPV_FORMAT_STRING, let raw = value.u.string else { continue }
                let text = String(cString: raw)
                if key == "name" { id = text }
                if key == "description" { name = text }
            }
            if !id.isEmpty { result.append((id, name.isEmpty ? id : name)) }
        }
        return result
    }

    func capturePNG() -> Data? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("meowx-art-\(UUID().uuidString).png")
        guard screenshot(to: url, format: "png") else { return nil }
        defer { try? FileManager.default.removeItem(at: url) }
        return try? Data(contentsOf: url)
    }

    func apply(_ settings: PlayerSettings) {
        setString("hwdec", settings.hardwareDecoding ? "videotoolbox" : "no")
        setString("demuxer-max-bytes", "\(settings.cacheMegabytes)MiB")
        setString("demuxer-max-back-bytes", "\(settings.cacheBackMegabytes)MiB")
        setString("slang", settings.subtitleLanguage)
        setString("alang", settings.audioLanguage)
        setString("screenshot-format", settings.screenshotFormat.rawValue)
        if !settings.subtitleFont.isEmpty { setString("sub-font", settings.subtitleFont) }
        setDouble("sub-font-size", settings.subtitleSize)
        setString("sub-color", settings.subtitleColorHex)
        setDouble("sub-pos", settings.subtitlePosition)
        setDouble("sub-border-size", settings.subtitleOutline)
        setString("sub-codepage", settings.subtitleEncoding)
        setString("tone-mapping", settings.toneMapping.rawValue)
        setString("audio-device", settings.audioDevice)
        setString("msg-level", settings.verboseLog ? "all=v" : "all=warn")
        _ = setAudioFilter(AudioChain.filter(normalize: settings.loudnessNormalize, night: settings.audioCompressor, bands: settings.equalizer))
    }

    func snapshot() -> EngineSnapshot {
        var snap = EngineSnapshot()
        snap.position = doubleProp("time-pos") ?? 0
        snap.duration = doubleProp("duration") ?? 0
        snap.paused = flagProp("pause")
        snap.volume = doubleProp("volume") ?? 100
        snap.muted = flagProp("mute")
        snap.speed = doubleProp("speed") ?? 1
        snap.buffering = flagProp("paused-for-cache")
        snap.cacheSeconds = doubleProp("demuxer-cache-duration") ?? 0
        snap.hwdec = stringProp("hwdec-current") ?? ""
        snap.width = intProp("video-params/w") ?? intProp("width") ?? 0
        snap.height = intProp("video-params/h") ?? intProp("height") ?? 0
        snap.fps = doubleProp("estimated-vf-fps") ?? doubleProp("container-fps") ?? 0
        snap.droppedFrames = intProp("frame-drop-count") ?? 0
        snap.videoCodec = stringProp("video-codec") ?? ""
        snap.audioCodec = stringProp("audio-codec") ?? ""
        snap.videoBitrate = doubleProp("video-bitrate") ?? 0
        snap.gamma = stringProp("video-params/gamma") ?? ""
        snap.primaries = stringProp("video-params/primaries") ?? ""
        return snap
    }

    func tracks() -> [MediaTrack] {
        let count = intProp("track-list/count") ?? 0
        guard count > 0 else { return [] }
        var result: [MediaTrack] = []
        for index in 0..<count {
            let prefix = "track-list/\(index)/"
            let kind = stringProp(prefix + "type") ?? ""
            guard kind == "audio" || kind == "sub" || kind == "video" else { continue }
            let id = intProp(prefix + "id") ?? index
            result.append(MediaTrack(
                id: id,
                kind: kind,
                title: stringProp(prefix + "title") ?? "",
                language: stringProp(prefix + "lang") ?? "",
                codec: stringProp(prefix + "codec") ?? "",
                channels: stringProp(prefix + "demux-channels") ?? "",
                albumArt: flagProp(prefix + "albumart"),
                isDefault: flagProp(prefix + "default"),
                isExternal: flagProp(prefix + "external"),
                isForced: flagProp(prefix + "forced")
            ))
        }
        return result
    }

    func stringProp(_ name: String) -> String? {
        guard started, let value = mpv_get_property_string(handle, name) else { return nil }
        defer { mpv_free(value) }
        let text = String(cString: value)
        return text.isEmpty ? nil : text
    }

    func doubleProp(_ name: String) -> Double? {
        guard started else { return nil }
        var value = 0.0
        guard mpv_get_property(handle, name, MPV_FORMAT_DOUBLE, &value) >= 0 else { return nil }
        return value
    }

    func intProp(_ name: String) -> Int? {
        guard started else { return nil }
        var value: Int64 = 0
        guard mpv_get_property(handle, name, MPV_FORMAT_INT64, &value) >= 0 else { return nil }
        return Int(value)
    }

    func flagProp(_ name: String) -> Bool {
        guard started else { return false }
        var value: Int32 = 0
        guard mpv_get_property(handle, name, MPV_FORMAT_FLAG, &value) >= 0 else { return false }
        return value != 0
    }

    func setString(_ name: String, _ value: String) {
        guard started else { return }
        mpv_set_property_string(handle, name, value)
    }

    func setDouble(_ name: String, _ value: Double) {
        guard started else { return }
        var copy = value
        mpv_set_property(handle, name, MPV_FORMAT_DOUBLE, &copy)
    }

    private func option(_ name: String, _ value: String) {
        let code = mpv_set_option_string(handle, name, value)
        if code < 0 {
            log.error("option \(name, privacy: .public)=\(value, privacy: .public) failed: \(self.errorText(code), privacy: .public)")
        }
    }

    private func observe(_ name: String, _ format: mpv_format) {
        let code = mpv_observe_property(handle, 0, name, format)
        if code < 0 {
            log.error("observe \(name, privacy: .public) failed: \(self.errorText(code), privacy: .public)")
        }
    }

    private func drainEvents() {
        guard started else { return }
        while true {
            guard let event = mpv_wait_event(handle, 0) else { return }
            let kind = event.pointee.event_id
            if kind == MPV_EVENT_NONE { return }
            if kind == MPV_EVENT_SHUTDOWN { return }
            if kind == MPV_EVENT_FILE_LOADED {
                delegate?.engineFileLoaded()
                continue
            }
            if kind == MPV_EVENT_END_FILE {
                delegate?.engineEnded(endReason(event))
                continue
            }
            if kind == MPV_EVENT_PROPERTY_CHANGE {
                handleProperty(event)
            }
            if kind == MPV_EVENT_LOG_MESSAGE, let raw = event.pointee.data {
                let message = raw.assumingMemoryBound(to: mpv_event_log_message.self).pointee
                if let text = message.text {
                    let line = String(cString: text).trimmingCharacters(in: .newlines)
                    if !line.isEmpty { AppLog.shared.add(line) }
                }
            }
        }
    }

    private func endReason(_ event: UnsafePointer<mpv_event>) -> EngineEnd {
        guard let data = event.pointee.data else { return .stop }
        let end = data.assumingMemoryBound(to: mpv_event_end_file.self)
        switch end.pointee.reason {
        case MPV_END_FILE_REASON_EOF:
            return .eof
        case MPV_END_FILE_REASON_ERROR:
            return .error(errorText(end.pointee.error))
        default:
            return .stop
        }
    }

    private func handleProperty(_ event: UnsafePointer<mpv_event>) {
        guard let data = event.pointee.data else { return }
        let property = data.assumingMemoryBound(to: mpv_event_property.self)
        guard let namePtr = property.pointee.name else { return }
        let name = String(cString: namePtr)
        switch name {
        case "pause":
            if property.pointee.format == MPV_FORMAT_FLAG, let raw = property.pointee.data {
                let paused = raw.assumingMemoryBound(to: Int32.self).pointee != 0
                delegate?.enginePauseChanged(paused)
            }
        case "paused-for-cache":
            if property.pointee.format == MPV_FORMAT_FLAG, let raw = property.pointee.data {
                let buffering = raw.assumingMemoryBound(to: Int32.self).pointee != 0
                delegate?.engineBufferingChanged(buffering)
            }
        case "eof-reached":
            if property.pointee.format == MPV_FORMAT_FLAG, let raw = property.pointee.data, raw.assumingMemoryBound(to: Int32.self).pointee != 0 {
                log.info("eof-reached")
                delegate?.engineEnded(.eof)
            }
        case "track-list":
            delegate?.engineTracksChanged()
        default:
            break
        }
    }

    private func errorText(_ code: Int32) -> String {
        guard let text = mpv_error_string(code) else { return "Unknown playback error" }
        return String(cString: text)
    }
}
