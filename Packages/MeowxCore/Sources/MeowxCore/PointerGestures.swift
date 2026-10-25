import Foundation

public enum VideoClick: Equatable, Sendable {
    case none
    case togglePause
    case toggleFullScreen
}

/// Single click waits. A second click cancels the pause and full-screens instead.
public struct PendingClick: Equatable, Sendable {
    public var pendingPause = false

    public init() {}

    public mutating func firstClick(pauseEnabled: Bool) {
        pendingPause = pauseEnabled
    }

    public mutating func secondClick() -> VideoClick {
        pendingPause = false
        return .toggleFullScreen
    }

    public mutating func dragged() {
        pendingPause = false
    }

    public mutating func fireIfStillPending() -> VideoClick {
        if pendingPause {
            pendingPause = false
            return .togglePause
        }
        return .none
    }
}

public struct ScrollAction: Equatable, Sendable {
    public var volumeDelta: Double
    public var seekDelta: Double

    public init(volumeDelta: Double, seekDelta: Double) {
        self.volumeDelta = volumeDelta
        self.seekDelta = seekDelta
    }

    public static func interpret(
        deltaX: Double,
        deltaY: Double,
        precise: Bool,
        momentum: Bool,
        volumeEnabled: Bool,
        seekEnabled: Bool
    ) -> ScrollAction {
        if momentum { return ScrollAction(volumeDelta: 0, seekDelta: 0) }
        let volumeScale = precise ? 0.25 : 5.0
        let seekScale = precise ? 0.08 : 5.0
        var volume = 0.0
        var seek = 0.0
        if volumeEnabled, abs(deltaY) >= abs(deltaX) {
            volume = clamp(deltaY * volumeScale, limit: precise ? 12 : 15)
        } else if seekEnabled, abs(deltaX) > abs(deltaY) {
            seek = clamp(deltaX * seekScale, limit: precise ? 8 : 30)
        }
        return ScrollAction(volumeDelta: volume, seekDelta: seek)
    }

    private static func clamp(_ value: Double, limit: Double) -> Double {
        min(limit, max(-limit, value))
    }
}

public enum TimeJump {
    /// Accepts seconds (`90`), `m:ss`, or `h:mm:ss`.
    public static func seconds(from text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ":").map(String.init)
        guard !parts.isEmpty, parts.count <= 3 else { return nil }
        var values: [Double] = []
        for (index, part) in parts.enumerated() {
            guard let value = Double(part), value.isFinite, value >= 0 else { return nil }
            if index > 0, value >= 60 { return nil }
            values.append(value)
        }
        return values.reduce(0) { $0 * 60 + $1 }
    }
}
