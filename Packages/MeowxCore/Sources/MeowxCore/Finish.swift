import Foundation

public enum EqualizerPreset: String, Codable, CaseIterable, Sendable {
    case flat
    case bass
    case voice
    case treble

    public var gains: [Double] {
        switch self {
        case .flat: return Array(repeating: 0, count: 10)
        case .bass: return [6, 5, 3, 1, 0, 0, 0, 0, 0, 0]
        case .voice: return [-2, -1, 0, 2, 3, 3, 2, 1, 0, -1]
        case .treble: return [0, 0, 0, 0, 0, 1, 2, 4, 5, 6]
        }
    }
}

public enum AudioChain {
    public static let frequencies: [Double] = [31.25, 62.5, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]

    public static func filter(normalize: Bool, night: Bool, bands: [Double] = []) -> String {
        var parts: [String] = []
        if normalize { parts.append("lavfi=[dynaudnorm]") }
        if night { parts.append("lavfi=[acompressor=threshold=0.1:ratio=6:attack=20:release=200:makeup=2]") }
        if let equalizer = equalizer(bands) { parts.append(equalizer) }
        return parts.joined(separator: ",")
    }

    /// A lavfi chain of ten octave equalizers. Flat gains are omitted so silence is not filtered.
    public static func equalizer(_ gains: [Double]) -> String? {
        let values = PlayerSettings.tenBands(gains)
        guard values.contains(where: { abs($0) > 0.05 }) else { return nil }
        let pieces = zip(frequencies, values).map { frequency, gain in
            String(format: "equalizer=f=%.2f:width_type=o:width=1:g=%.1f", frequency, gain)
        }
        return "lavfi=[\(pieces.joined(separator: ","))]"
    }
}

public enum VersionCompare {
    public static func isNewer(_ remote: String, than local: String) -> Bool {
        let left = parts(remote)
        let right = parts(local)
        guard !left.isEmpty else { return false }
        let count = max(left.count, right.count)
        for index in 0..<count {
            let a = index < left.count ? left[index] : 0
            let b = index < right.count ? right[index] : 0
            if a != b { return a > b }
        }
        return false
    }

    static func parts(_ raw: String) -> [Int] {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.lowercased().hasPrefix("v") { text.removeFirst() }
        return text.split(whereSeparator: { $0 == "." || $0 == "-" }).compactMap { piece in
            let digits = piece.prefix(while: \.isNumber)
            return digits.isEmpty ? nil : Int(digits)
        }
    }
}

public enum ReleaseTag {
    public static func parse(_ data: Data) -> String? {
        struct Box: Decodable { let tag_name: String? }
        guard let name = try? JSONDecoder().decode(Box.self, from: data).tag_name else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

public enum LogPrivacy {
    public static func redact(_ text: String, includePaths: Bool) -> String {
        guard !includePaths else { return text }
        var output = ""
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            if character == "/" || (character == "~" && nextIsPath(text, index)) {
                output += "[path]"
                index = text.index(after: index)
                while index < text.endIndex, !text[index].isWhitespace { index = text.index(after: index) }
            } else {
                output.append(character)
                index = text.index(after: index)
            }
        }
        return output
    }

    private static func nextIsPath(_ text: String, _ index: String.Index) -> Bool {
        let next = text.index(after: index)
        return next < text.endIndex && (text[next] == "/" || text[next].isLetter)
    }
}

public enum SleepPlan {
    public static func fires(started: Date?, minutes: Int, now: Date) -> Bool {
        guard minutes > 0, let started else { return false }
        return now.timeIntervalSince(started) >= Double(minutes) * 60
    }
}

public enum StopAfter: String, Codable, CaseIterable, Sendable {
    case none
    case file
    case playlist
}

public enum PlaybackStop {
    public static func endsHere(request: StopAfter, hasNextFile: Bool) -> Bool {
        switch request {
        case .none: return false
        case .file: return true
        case .playlist: return !hasNextFile
        }
    }
}

public struct TrackMemory: Codable, Equatable, Sendable {
    public var audioID: Int?
    public var subtitleID: Int?
    public var subtitleDelay: Double?
    public var zoom: Double?

    public init(audioID: Int? = nil, subtitleID: Int? = nil, subtitleDelay: Double? = nil, zoom: Double? = nil) {
        self.audioID = audioID
        self.subtitleID = subtitleID
        self.subtitleDelay = subtitleDelay
        self.zoom = zoom
    }
}

public final class TrackMemoryStore: @unchecked Sendable {
    private let fileURL: URL
    private let lock = NSLock()
    private var entries: [String: TrackMemory] = [:]

    public init(directory: URL) {
        fileURL = directory.appendingPathComponent("track-memory.json")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: fileURL) {
            entries = (try? JSONDecoder().decode([String: TrackMemory].self, from: data)) ?? [:]
        }
    }

    public func recall(_ key: String) -> TrackMemory? {
        lock.lock()
        defer { lock.unlock() }
        return entries[key]
    }

    public func save(_ memory: TrackMemory, for key: String) {
        lock.lock()
        defer { lock.unlock() }
        entries[key] = memory
        if let data = try? JSONEncoder().encode(entries) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}

public struct MediaFacts: Equatable, Sendable {
    public var container: String
    public var path: String
    public var byteCount: Int?
    public var video: String
    public var audio: String
    public var subtitles: String
    public var bitrate: String
    public var hdr: String
    public var hardware: String

    public init(container: String, path: String, byteCount: Int?, video: String, audio: String, subtitles: String, bitrate: String, hdr: String, hardware: String) {
        self.container = container
        self.path = path
        self.byteCount = byteCount
        self.video = video
        self.audio = audio
        self.subtitles = subtitles
        self.bitrate = bitrate
        self.hdr = hdr
        self.hardware = hardware
    }

    public func text() -> String {
        [
            "Container: \(shown(container))",
            "Path: \(shown(path))",
            "Size: \(size)",
            "Video: \(shown(video))",
            "Audio: \(shown(audio))",
            "Subtitles: \(shown(subtitles))",
            "Bitrate: \(shown(bitrate))",
            "HDR: \(shown(hdr))",
            "Hardware decoding: \(shown(hardware))"
        ].joined(separator: "\n")
    }

    private var size: String {
        guard let byteCount, byteCount > 0 else { return "—" }
        if byteCount >= 1_000_000_000 { return String(format: "%.2f GB", Double(byteCount) / 1_000_000_000) }
        if byteCount >= 1_000_000 { return String(format: "%.1f MB", Double(byteCount) / 1_000_000) }
        return "\(byteCount) bytes"
    }

    private func shown(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }
}
