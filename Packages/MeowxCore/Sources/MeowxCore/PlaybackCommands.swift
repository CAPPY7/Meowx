import Foundation

/// Whether a key must be left for a text field, sheet, or dialog.
public struct KeyRouting: Equatable, Sendable {
    public var appModal: Bool
    public var sheetAttached: Bool
    public var firstResponderIsText: Bool

    public init(appModal: Bool, sheetAttached: Bool, firstResponderIsText: Bool) {
        self.appModal = appModal
        self.sheetAttached = sheetAttached
        self.firstResponderIsText = firstResponderIsText
    }

    /// True means the player must not handle the key.
    public var leaveEventForText: Bool {
        appModal || sheetAttached || firstResponderIsText
    }
}

public enum ShortcutKey {
    public static func token(for keyCode: Int) -> String? {
        switch keyCode {
        case 49: return "space"
        case 123: return "left"
        case 124: return "right"
        case 125: return "down"
        case 126: return "up"
        case 53: return "escape"
        case 115: return "home"
        case 119: return "end"
        case 0: return "a"
        case 1: return "s"
        case 3: return "f"
        case 6: return "z"
        case 7: return "x"
        case 9: return "v"
        case 14: return "e"
        case 15: return "r"
        case 17: return "t"
        case 31: return "o"
        case 32: return "u"
        case 34: return "i"
        case 35: return "p"
        case 37: return "l"
        case 38: return "j"
        case 30: return "bracketright"
        case 33: return "bracketleft"
        case 42: return "backslash"
        case 43: return "comma"
        case 46: return "m"
        case 47: return "period"
        case 29, 82: return "0"
        case 18, 83: return "1"
        case 19, 84: return "2"
        case 20, 85: return "3"
        case 21, 86: return "4"
        case 23, 87: return "5"
        case 22, 88: return "6"
        case 26, 89: return "7"
        case 28, 91: return "8"
        case 25, 92: return "9"
        default: return nil
        }
    }
}

public enum PlaybackJump {
    /// Digit 0 is 0%, digit 1 is 10%, through digit 9 at 90%.
    public static func seconds(digit: Int, duration: Double) -> Double? {
        guard (0...9).contains(digit), duration > 0, duration.isFinite else { return nil }
        return duration * (Double(digit) / 10)
    }
}

public enum LoopCycle {
    public enum Step: Equatable, Sendable {
        case setA
        case setB
        case clear
    }

    public static func next(hasA: Bool, hasB: Bool) -> Step {
        if !hasA { return .setA }
        if !hasB { return .setB }
        return .clear
    }
}

public enum AspectCycle {
    public static let presets = ["", "16:9", "4:3", "21:9", "1:1"]

    public static func next(current: String) -> String {
        let normalized = (current == "no" || current == "-1") ? "" : current
        let index = presets.firstIndex(of: normalized) ?? -1
        return presets[(index + 1) % presets.count]
    }

    public static func mpvValue(_ preset: String) -> String {
        preset.isEmpty ? "no" : preset
    }

    public static func label(_ preset: String) -> String {
        preset.isEmpty || preset == "no" || preset == "-1" ? "Aspect: default" : "Aspect: \(preset)"
    }
}

public enum RotationCycle {
    public static func next(degrees: Int) -> Int {
        let quarter = ((degrees % 360) + 360) % 360 / 90
        return ((quarter + 1) % 4) * 90
    }
}

public struct FrameSize: Equatable, Sendable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public enum WindowFit {
    public static func scaled(videoWidth: Int, videoHeight: Int, scale: Double, maxWidth: Double, maxHeight: Double) -> FrameSize? {
        guard videoWidth > 0, videoHeight > 0, scale > 0, scale.isFinite else { return nil }
        return fittedBox(
            width: Double(videoWidth) * scale,
            height: Double(videoHeight) * scale,
            maxWidth: maxWidth,
            maxHeight: maxHeight
        )
    }

    public static func fitted(videoWidth: Int, videoHeight: Int, maxWidth: Double, maxHeight: Double) -> FrameSize? {
        guard videoWidth > 0, videoHeight > 0 else { return nil }
        return fittedBox(
            width: Double(videoWidth),
            height: Double(videoHeight),
            maxWidth: maxWidth,
            maxHeight: maxHeight
        )
    }

    private static func fittedBox(width: Double, height: Double, maxWidth: Double, maxHeight: Double) -> FrameSize? {
        guard width > 0, height > 0 else { return nil }
        var fittedWidth = width
        var fittedHeight = height
        if maxWidth > 0, maxHeight > 0, (fittedWidth > maxWidth || fittedHeight > maxHeight) {
            let fit = min(maxWidth / fittedWidth, maxHeight / fittedHeight)
            fittedWidth *= fit
            fittedHeight *= fit
        }
        return FrameSize(width: fittedWidth.rounded(), height: fittedHeight.rounded())
    }
}
