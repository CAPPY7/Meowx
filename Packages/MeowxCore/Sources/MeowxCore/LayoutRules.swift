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
