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
        case 116: return "pageup"
        case 121: return "pagedown"
        case 0: return "a"
        case 1: return "s"
        case 3: return "f"
        case 2: return "d"
        case 5: return "g"
        case 6: return "z"
        case 8: return "c"
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

public struct MediaChapter: Equatable, Sendable, Identifiable {
    public var index: Int
    public var title: String
    public var time: Double
    public var id: Int { index }

    public init(index: Int, title: String, time: Double) {
        self.index = index
        self.title = title
        self.time = time
    }
}

public enum ChapterNav {
    /// Chapter whose start is still at or just before the playhead. -1 when there are none.
    public static func index(at position: Double, chapters: [MediaChapter]) -> Int {
        guard position.isFinite else { return -1 }
        var found = -1
        for chapter in chapters where chapter.time.isFinite && chapter.time <= position + 0.15 {
            found = chapter.index
        }
        return found
    }

    /// Next or previous chapter. A negative current index means playback is before the first chapter.
    public static func neighbor(current: Int, count: Int, direction: Int) -> Int? {
        guard count > 0, direction != 0 else { return nil }
        if current < 0 { return direction > 0 ? 0 : nil }
        let next = current + (direction > 0 ? 1 : -1)
        guard next >= 0, next < count else { return nil }
        return next
    }

    /// Fractions for seek-bar marks. A chapter at the very start or end is skipped.
    public static func tickFractions(times: [Double], duration: Double) -> [Double] {
        guard duration > 0, duration.isFinite else { return [] }
        return times.compactMap { time in
            guard time.isFinite, time > 0.4, time < duration - 0.4 else { return nil }
            return min(1, max(0, time / duration))
        }
    }

    public static func displayTitle(index: Int, title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Chapter \(index + 1)" : trimmed
    }

    public static func status(index: Int, title: String, count: Int) -> String {
        let total = max(count, 1)
        return "\(displayTitle(index: index, title: title)) (\(index + 1)/\(total))"
    }
}

public enum VideoFlip {
    public static func filter(horizontal: Bool, vertical: Bool) -> String {
        switch (horizontal, vertical) {
        case (false, false): return ""
        case (true, false): return "hflip"
        case (false, true): return "vflip"
        case (true, true): return "hflip,vflip"
        }
    }
}

public enum CropPreset {
    public static let order = ["", "16:9", "4:3", "2.35:1", "1:1"]

    public static func next(_ current: String) -> String {
        guard let index = order.firstIndex(of: current) else { return "16:9" }
        return order[(index + 1) % order.count]
    }

    public static func label(_ preset: String) -> String {
        preset.isEmpty ? "Crop: none" : "Crop: \(preset)"
    }

    /// Centered `WIDTHxHEIGHT` for mpv `video-crop`, or nil when there is nothing to crop.
    public static func rectangle(videoWidth: Int, videoHeight: Int, preset: String) -> String? {
        guard videoWidth >= 2, videoHeight >= 2 else { return nil }
        let ratio: Double
        switch preset {
        case "16:9": ratio = 16.0 / 9.0
        case "4:3": ratio = 4.0 / 3.0
        case "2.35:1": ratio = 2.35
        case "1:1": ratio = 1
        default: return nil
        }
        let source = Double(videoWidth) / Double(videoHeight)
        var width = videoWidth
        var height = videoHeight
        if source > ratio + 0.001 {
            width = even(Int((Double(videoHeight) * ratio).rounded()), limit: videoWidth)
        } else if source < ratio - 0.001 {
            height = even(Int((Double(videoWidth) / ratio).rounded()), limit: videoHeight)
        } else {
            return nil
        }
        guard width >= 2, height >= 2, width < videoWidth || height < videoHeight else { return nil }
        return "\(width)x\(height)"
    }

    private static func even(_ value: Int, limit: Int) -> Int {
        var number = min(limit, max(2, value))
        if number % 2 != 0 { number -= 1 }
        return max(2, number)
    }
}

public struct PictureLevels: Equatable, Sendable {
    public var brightness: Double
    public var contrast: Double
    public var saturation: Double
    public var gamma: Double
    public var hue: Double

    public static let neutral = PictureLevels(brightness: 0, contrast: 0, saturation: 0, gamma: 0, hue: 0)

    public init(brightness: Double, contrast: Double, saturation: Double, gamma: Double, hue: Double) {
        self.brightness = brightness
        self.contrast = contrast
        self.saturation = saturation
        self.gamma = gamma
        self.hue = hue
    }

    public var isNeutral: Bool {
        Self.nearZero(brightness) && Self.nearZero(contrast) && Self.nearZero(saturation)
            && Self.nearZero(gamma) && Self.nearZero(hue)
    }

    public static func clamped(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(100, max(-100, value))
    }

    public func clamped() -> PictureLevels {
        PictureLevels(
            brightness: Self.clamped(brightness),
            contrast: Self.clamped(contrast),
            saturation: Self.clamped(saturation),
            gamma: Self.clamped(gamma),
            hue: Self.clamped(hue)
        )
    }

    private static func nearZero(_ value: Double) -> Bool {
        abs(value) < 0.05
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

/// One end-of-file signal per visit to the end. A second event for the same ending does nothing.
public struct EndOfFileGate: Equatable, Sendable {
    private var consumed = false

    public init() {}

    public mutating func fileDidLoad() {
        consumed = false
    }

    /// Re-arm only after playback has moved away from the end.
    public mutating func noteProgress(position: Double, duration: Double) {
        guard duration > 1, position < duration - 1 else { return }
        consumed = false
    }

    public mutating func consume(reached: Bool) -> Bool {
        guard reached else { return false }
        if consumed { return false }
        consumed = true
        return true
    }
}

public enum MediaOpenCheck {
    public static func problem(byteCount: Int, header: Data) -> String? {
        if byteCount == 0 { return "That file is empty." }
        guard !header.isEmpty else { return nil }
        let sample = header.prefix(64)
        let text = sample.allSatisfy { byte in
            byte == 9 || byte == 10 || byte == 13 || (byte >= 32 && byte < 127)
        }
        guard text else { return nil }
        if sample.count >= 12 || byteCount == sample.count {
            return "That file looks like text, not video or audio."
        }
        return nil
    }
}
