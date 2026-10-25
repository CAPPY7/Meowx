import Foundation

public struct ShortcutInput: Equatable, Sendable {
    public var token: String
    public var command: Bool
    public var shift: Bool
    public var option: Bool
    public var control: Bool

    public init(token: String, command: Bool = false, shift: Bool = false, option: Bool = false, control: Bool = false) {
        self.token = token
        self.command = command
        self.shift = shift
        self.option = option
        self.control = control
    }
}

public struct ShortcutCommand: Equatable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let group: String
    public let token: String
    public let command: Bool
    public let shift: Bool
    public let option: Bool
    public let control: Bool

    public init(
        id: String,
        title: String,
        group: String,
        token: String = "",
        command: Bool = false,
        shift: Bool = false,
        option: Bool = false,
        control: Bool = false
    ) {
        self.id = id
        self.title = title
        self.group = group
        self.token = token
        self.command = command
        self.shift = shift
        self.option = option
        self.control = control
    }

    public var combo: String {
        guard !token.isEmpty else { return "" }
        return [control ? "control" : nil, option ? "option" : nil, shift ? "shift" : nil, command ? "command" : nil, token]
            .compactMap { $0 }
            .joined(separator: "+")
    }

    public var display: String {
        guard !token.isEmpty else { return "" }
        var parts: [String] = []
        if control { parts.append("Ctrl") }
        if option { parts.append("Opt") }
        if shift { parts.append("Shift") }
        if command { parts.append("Cmd") }
        parts.append(Self.keyName(token))
        return parts.joined(separator: "+")
    }

    public func help(title customTitle: String? = nil) -> String {
        let name = customTitle ?? title
        return display.isEmpty ? name : "\(name) (\(display))"
    }

    public func matches(_ input: ShortcutInput) -> Bool {
        !token.isEmpty
            && token == input.token
            && command == input.command
            && shift == input.shift
            && option == input.option
            && control == input.control
    }

    private static func keyName(_ token: String) -> String {
        switch token {
        case "space": return "Space"
        case "left": return "Left"
        case "right": return "Right"
        case "up": return "Up"
        case "down": return "Down"
        case "escape": return "Esc"
        case "home": return "Home"
        case "end": return "End"
        case "pageup": return "Page Up"
        case "pagedown": return "Page Down"
        case "bracketleft": return "["
        case "bracketright": return "]"
        case "backslash": return "\\"
        case "slash": return "/"
        case "comma": return ","
        case "period": return "."
        default: return token.uppercased()
        }
    }
}

public enum ShortcutCatalog {
    public static let all: [ShortcutCommand] = [
        ShortcutCommand(id: "playPause", title: "Play or pause", group: "Playback", token: "space"),
        ShortcutCommand(id: "previous", title: "Previous", group: "Playback", token: "left", command: true),
        ShortcutCommand(id: "next", title: "Next", group: "Playback", token: "right", command: true),
        ShortcutCommand(id: "seekBack", title: "Seek back 5 seconds", group: "Playback", token: "left"),
        ShortcutCommand(id: "seekForward", title: "Seek forward 5 seconds", group: "Playback", token: "right"),
        ShortcutCommand(id: "seekBack30", title: "Seek back 30 seconds", group: "Playback", token: "left", shift: true),
        ShortcutCommand(id: "seekForward30", title: "Seek forward 30 seconds", group: "Playback", token: "right", shift: true),
        ShortcutCommand(id: "jump0", title: "Jump to 0%", group: "Playback", token: "0"),
        ShortcutCommand(id: "jump1", title: "Jump to 10%", group: "Playback", token: "1"),
        ShortcutCommand(id: "jump2", title: "Jump to 20%", group: "Playback", token: "2"),
        ShortcutCommand(id: "jump3", title: "Jump to 30%", group: "Playback", token: "3"),
        ShortcutCommand(id: "jump4", title: "Jump to 40%", group: "Playback", token: "4"),
        ShortcutCommand(id: "jump5", title: "Jump to 50%", group: "Playback", token: "5"),
        ShortcutCommand(id: "jump6", title: "Jump to 60%", group: "Playback", token: "6"),
        ShortcutCommand(id: "jump7", title: "Jump to 70%", group: "Playback", token: "7"),
        ShortcutCommand(id: "jump8", title: "Jump to 80%", group: "Playback", token: "8"),
        ShortcutCommand(id: "jump9", title: "Jump to 90%", group: "Playback", token: "9"),
        ShortcutCommand(id: "seekStart", title: "Go to start", group: "Playback", token: "home"),
        ShortcutCommand(id: "seekEnd", title: "Go to end", group: "Playback", token: "end"),
        ShortcutCommand(id: "previousChapter", title: "Previous chapter", group: "Playback", token: "pageup"),
        ShortcutCommand(id: "nextChapter", title: "Next chapter", group: "Playback", token: "pagedown"),
        ShortcutCommand(id: "volumeUp", title: "Volume up", group: "Audio", token: "up"),
        ShortcutCommand(id: "volumeDown", title: "Volume down", group: "Audio", token: "down"),
        ShortcutCommand(id: "volumeUp10", title: "Volume up 10", group: "Audio", token: "up", shift: true),
        ShortcutCommand(id: "volumeDown10", title: "Volume down 10", group: "Audio", token: "down", shift: true),
        ShortcutCommand(id: "mute", title: "Mute", group: "Audio", token: "m"),
        ShortcutCommand(id: "cycleAudio", title: "Audio tracks", group: "Audio", token: "a"),
        ShortcutCommand(id: "previousAudio", title: "Previous audio track", group: "Audio", token: "a", shift: true),
        ShortcutCommand(id: "audioDelayEarlier", title: "Audio delay earlier", group: "Audio", token: "z", option: true),
        ShortcutCommand(id: "audioDelayLater", title: "Audio delay later", group: "Audio", token: "x", option: true),
        ShortcutCommand(id: "cycleSubtitles", title: "Subtitles", group: "Subtitles", token: "s"),
        ShortcutCommand(id: "previousSubtitle", title: "Previous subtitle", group: "Subtitles", token: "s", shift: true),
        ShortcutCommand(id: "toggleSubtitleVisibility", title: "Show or hide subtitles", group: "Subtitles", token: "v"),
        ShortcutCommand(id: "subDelayEarlier", title: "Subtitle delay earlier", group: "Subtitles", token: "z"),
        ShortcutCommand(id: "subDelayLater", title: "Subtitle delay later", group: "Subtitles", token: "x"),
        ShortcutCommand(id: "speedDown", title: "Speed down", group: "Playback", token: "bracketleft"),
        ShortcutCommand(id: "speedUp", title: "Speed up", group: "Playback", token: "bracketright"),
        ShortcutCommand(id: "speedReset", title: "Reset speed", group: "Playback", token: "backslash"),
        ShortcutCommand(id: "frameBack", title: "Previous frame", group: "Playback", token: "comma"),
        ShortcutCommand(id: "frameForward", title: "Next frame", group: "Playback", token: "period"),
        ShortcutCommand(id: "jump", title: "Go to time", group: "Playback", token: "j", command: true),
        ShortcutCommand(id: "loopCycle", title: "Loop A, then B, then clear", group: "Playback", token: "l"),
        ShortcutCommand(id: "loopFile", title: "Loop current file", group: "Playback", token: "l", shift: true),
        ShortcutCommand(id: "screenshot", title: "Screenshot", group: "Playback", token: "s", command: true, shift: true),
        ShortcutCommand(id: "rotate", title: "Rotate 90 degrees", group: "Video", token: "r"),
        ShortcutCommand(id: "cycleAspect", title: "Cycle aspect ratio", group: "Video", token: "e"),
        ShortcutCommand(id: "flipHorizontal", title: "Flip horizontal", group: "Video", token: "r", shift: true),
        ShortcutCommand(id: "flipVertical", title: "Flip vertical", group: "Video", token: "r", option: true),
        ShortcutCommand(id: "cycleCrop", title: "Cycle crop", group: "Video", token: "e", shift: true),
        ShortcutCommand(id: "deinterlace", title: "Deinterlace", group: "Video", token: "d"),
        ShortcutCommand(id: "resetZoom", title: "Reset zoom and pan", group: "Video", token: "g"),
        ShortcutCommand(id: "picture", title: "Picture adjustments", group: "Video", token: "c"),
        ShortcutCommand(id: "fullScreen", title: "Full screen", group: "Window", token: "f"),
        ShortcutCommand(id: "fullScreenSystem", title: "Full screen", group: "Window", token: "f", command: true, control: true),
        ShortcutCommand(id: "leaveFullScreen", title: "Leave full screen", group: "Window", token: "escape"),
        ShortcutCommand(id: "pictureInPicture", title: "Floating window", group: "Window", token: "p"),
        ShortcutCommand(id: "alwaysOnTop", title: "Always on top", group: "Window", token: "t", command: true),
        ShortcutCommand(id: "windowHalf", title: "Window 50%", group: "Window", token: "1", command: true),
        ShortcutCommand(id: "windowActual", title: "Window 100%", group: "Window", token: "2", command: true),
        ShortcutCommand(id: "windowDouble", title: "Window 200%", group: "Window", token: "3", command: true),
        ShortcutCommand(id: "windowFit", title: "Fit window to screen", group: "Window", token: "0", command: true),
        ShortcutCommand(id: "stats", title: "Stats", group: "Window", token: "i"),
        ShortcutCommand(id: "shortcuts", title: "Keyboard shortcuts", group: "Window", token: "slash", shift: true),
        ShortcutCommand(id: "open", title: "Open", group: "File", token: "o", command: true),
        ShortcutCommand(id: "openURL", title: "Open URL", group: "File", token: "u", command: true),
        ShortcutCommand(id: "pasteLink", title: "Paste link", group: "File", token: "v", command: true),
        ShortcutCommand(id: "addToPlaylist", title: "Add to playlist", group: "File", token: "o", command: true, shift: true),
        ShortcutCommand(id: "showPlaylist", title: "Show playlist", group: "Window"),
        ShortcutCommand(id: "shuffle", title: "Shuffle", group: "Playback"),
        ShortcutCommand(id: "repeat", title: "Repeat", group: "Playback"),
        ShortcutCommand(id: "loopStart", title: "Set loop start", group: "Playback"),
        ShortcutCommand(id: "loopEnd", title: "Set loop end", group: "Playback"),
        ShortcutCommand(id: "seekBar", title: "Drag to seek. Left/Right 5 s, Shift 30 s. Chapter marks use Page Up and Page Down", group: "Playback"),
        ShortcutCommand(id: "chapters", title: "Chapters (Page Up / Page Down)", group: "Playback"),
        ShortcutCommand(id: "volumeSlider", title: "Volume", group: "Audio")
    ]

    public static func command(_ id: String) -> ShortcutCommand? {
        all.first { $0.id == id }
    }

    public static func help(_ id: String, title: String? = nil) -> String {
        command(id)?.help(title: title) ?? (title ?? id)
    }

    public static func match(_ input: ShortcutInput) -> ShortcutCommand? {
        all.first { $0.matches(input) }
    }

    public static var markdownTable: String {
        let keyed = all.filter { !$0.token.isEmpty }
        let lines = keyed.map { "| \($0.display) | \($0.title) |" }
        return (["| Key | Action |", "| --- | --- |"] + lines).joined(separator: "\n")
    }
}

public enum TrackLabel {
    public static func text(
        kind: String,
        id: Int,
        language: String,
        title: String,
        codec: String,
        channels: String,
        isDefault: Bool,
        isExternal: Bool,
        isForced: Bool,
        albumArt: Bool
    ) -> String {
        let language = language.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        var names = [language, title].filter { !$0.isEmpty }
        if names.isEmpty {
            names = [kind == "sub" ? "Subtitle \(id)" : (kind == "audio" ? "Audio \(id)" : "Video \(id)")]
        }
        var technical: [String] = []
        if !codec.isEmpty { technical.append(codec.uppercased()) }
        if !channels.isEmpty { technical.append(channels) }
        if albumArt { technical.append("picture") }
        var line = names.joined(separator: " - ")
        if !technical.isEmpty {
            line += " - " + technical.joined(separator: " ")
        }
        var tags: [String] = []
        if isDefault { tags.append("default") }
        if isExternal { tags.append("external") }
        if isForced { tags.append("forced") }
        if !tags.isEmpty {
            line += " (\(tags.joined(separator: ", ")))"
        }
        return line
    }
}
