import Foundation

/// Whether the playlist panel is on screen. It follows the chrome, unless the pointer is still inside it.
public enum PlaylistPanel {
    public static func visible(open: Bool, chromeVisible: Bool, pointerInside: Bool) -> Bool {
        open && (chromeVisible || pointerInside)
    }
}

public enum PlaylistQuery {
    public static func filter(_ items: [PlaylistItem], query: String) -> [PlaylistItem] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return items }
        return items.filter {
            $0.title.localizedCaseInsensitiveContains(needle)
                || $0.url.lastPathComponent.localizedCaseInsensitiveContains(needle)
        }
    }
}

/// Gap after the real traffic-light buttons. Full screen and a missing button both use zero.
public enum TrafficClearance {
    public static func inset(buttonMaxX: Double, fullscreen: Bool) -> Double {
        guard !fullscreen, buttonMaxX.isFinite, buttonMaxX > 1 else { return 0 }
        return buttonMaxX + 8
    }
}

public enum HDRBadge {
    public static func isHDR(gamma: String, primaries: String) -> Bool {
        let transfer = gamma.lowercased()
        let color = primaries.lowercased()
        return transfer == "pq" || transfer == "hlg" || color == "bt.2020"
    }
}

public enum OpeningCue {
    /// How long the file name stays at the top after playback starts.
    public static let seconds: Double = 4
}

public enum VolumeTrack {
    public static func fraction(volume: Double, muted: Bool) -> Double {
        guard !muted, volume.isFinite else { return 0 }
        return min(1, max(0, volume / 200))
    }

    /// Center of the knob. It stays on the bar and lines up with the filled part.
    public static func knobCenter(fraction: Double, width: Double, knob: Double) -> Double {
        guard width.isFinite, width > 0 else { return 0 }
        let mark = min(1, max(0, fraction)) * width
        let half = max(0, knob) / 2
        if width <= knob { return width / 2 }
        return min(max(half, mark), width - half)
    }
}

public enum SubtitleStyle {
    public static let size: Double = 36
    public static let outline: Double = 2

    /// The first release used 55 pt and a 1 pt outline, which reads too large on a laptop picture.
    public static func migrated(size: Double, outline: Double) -> (size: Double, outline: Double) {
        if size == 55, outline == 1 { return (Self.size, Self.outline) }
        return (size, outline)
    }
}

public enum MediaLine {
    public static func detail(width: Int, height: Int, codec: String) -> String {
        var parts: [String] = []
        if width > 0, height > 0 { parts.append("\(width)×\(height)") }
        let name = codec.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { parts.append(name) }
        return parts.joined(separator: " · ")
    }
}

public enum BufferSpan {
    /// Played fraction, and the lighter cached segment ahead of the playhead.
    public static func fractions(position: Double, cachedAhead: Double, duration: Double) -> (played: Double, bufferStart: Double, bufferEnd: Double) {
        guard duration > 0, duration.isFinite else { return (0, 0, 0) }
        let played = min(1, max(0, position / duration))
        let ahead = cachedAhead.isFinite ? max(0, cachedAhead) : 0
        let end = min(1, max(played, (max(0, position) + ahead) / duration))
        return (played, played, end)
    }
}

public enum TimeReadout {
    /// The right-hand clock is either the duration or the time left.
    public static func seconds(position: Double, duration: Double, remaining: Bool) -> Double {
        guard duration > 0, duration.isFinite else { return 0 }
        let played = min(max(0, position), duration)
        return remaining ? duration - played : duration
    }
}

public enum SpeedPresets {
    public static let values: [Double] = [0.5, 0.75, 1, 1.25, 1.5, 2, 3, 4]
}

public enum PasteLink {
    /// A clipboard string that is a link or a local path. Plain words are not turned into a URL.
    public static func url(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(where: \.isNewline) else { return nil }
        if trimmed.hasPrefix("/") || trimmed.hasPrefix("~") {
            return URL(fileURLWithPath: (trimmed as NSString).expandingTildeInPath)
        }
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased() else { return nil }
        switch scheme {
        case "http", "https", "file", "rtmp", "rtsp":
            return url
        default:
            return nil
        }
    }
}

public struct LyricLine: Equatable, Sendable {
    public var time: Double
    public var text: String

    public init(time: Double, text: String) {
        self.time = time
        self.text = text
    }
}

public enum LyricsFile {
    public static func parse(_ text: String) -> [LyricLine] {
        var lines: [LyricLine] = []
        for raw in text.split(whereSeparator: \.isNewline) {
            let line = String(raw).trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("["), let close = line.firstIndex(of: "]") else { continue }
            let stamp = String(line[line.index(after: line.startIndex)..<close])
            let words = line[line.index(after: close)...].trimmingCharacters(in: .whitespaces)
            guard let time = time(from: stamp), !words.isEmpty else { continue }
            lines.append(LyricLine(time: time, text: words))
        }
        return lines.sorted { $0.time < $1.time }
    }

    public static func current(at position: Double, lines: [LyricLine]) -> String? {
        guard position.isFinite else { return nil }
        var found: String?
        for line in lines where line.time <= position + 0.05 {
            found = line.text
        }
        return found
    }

    private static func time(from stamp: String) -> Double? {
        let parts = stamp.split(separator: ":")
        guard parts.count == 2 || parts.count == 3 else { return nil }
        let numbers = parts.map { Double($0) }
        guard numbers.allSatisfy({ $0 != nil }) else { return nil }
        if parts.count == 2 {
            return (numbers[0] ?? 0) * 60 + (numbers[1] ?? 0)
        }
        return (numbers[0] ?? 0) * 3600 + (numbers[1] ?? 0) * 60 + (numbers[2] ?? 0)
    }
}

public enum ThumbnailCache {
    public static func key(path: String, fileSize: Int) -> String {
        var hash: UInt64 = 14695981039346656037
        for byte in Data("\(path)#\(fileSize)".utf8) {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return String(format: "%016llx", hash)
    }
}
