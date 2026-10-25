import Foundation

public enum AccessibilityPaint {
    public static func usesSolidSurface(reduceTransparency: Bool, increaseContrast: Bool) -> Bool {
        reduceTransparency || increaseContrast
    }

    public static func ringWidth(increaseContrast: Bool) -> Double {
        increaseContrast ? 2 : 1
    }

    public static func fade(reduceMotion: Bool) -> Double {
        DesignTokens.duration(DesignTokens.fade, reduceMotion: reduceMotion)
    }
}

public enum CursorChrome {
    /// A cursor hide can post a fake move. Ignore activity inside this window so the chrome does not flash back.
    public static func shouldIgnoreActivity(hiddenAt: Date?, now: Date, window: Double = 0.2) -> Bool {
        guard let hiddenAt, window > 0 else { return false }
        let elapsed = now.timeIntervalSince(hiddenAt)
        return elapsed >= 0 && elapsed < window
    }
}

public enum TickGate {
    public static func shouldWrite<T: Equatable>(_ current: T, _ next: T) -> Bool {
        current != next
    }

    public static func shouldWrite(_ current: Double, _ next: Double, epsilon: Double) -> Bool {
        guard next.isFinite else { return false }
        return abs(current - next) > epsilon
    }
}

public enum SeekAccess {
    public static func value(position: Double, duration: Double, chapterTitle: String?) -> String {
        let played = clock(position)
        let total = clock(duration)
        let base = "\(played) of \(total)"
        let title = chapterTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !title.isEmpty else { return base }
        return "\(base), \(title)"
    }

    private static func clock(_ seconds: Double) -> String {
        let total = Int(max(0, seconds).rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, secs) }
        return String(format: "%d:%02d", minutes, secs)
    }
}
