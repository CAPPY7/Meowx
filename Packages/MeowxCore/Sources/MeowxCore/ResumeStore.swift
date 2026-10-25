import Foundation

public final class ResumeStore: @unchecked Sendable {
    public struct Entry: Codable, Equatable, Sendable {
        public var position: Double
        public var duration: Double
        public var updatedAt: Date

        public init(position: Double, duration: Double, updatedAt: Date) {
            self.position = position
            self.duration = duration
            self.updatedAt = updatedAt
        }
    }

    private let fileURL: URL
    private let lock = NSLock()
    private var entries: [String: Entry] = [:]

    public init(directory: URL) {
        fileURL = directory.appendingPathComponent("resume.json")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        load()
    }

    public static func key(for url: URL) -> String {
        if url.isFileURL {
            let path = url.standardizedFileURL.path
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return "file:\(path)#\(size)"
        }
        return url.absoluteString
    }

    public func position(for key: String) -> Double? {
        lock.lock()
        defer { lock.unlock() }
        return entries[key]?.position
    }

    public func duration(for key: String) -> Double? {
        lock.lock()
        defer { lock.unlock() }
        guard let duration = entries[key]?.duration, duration > 0 else { return nil }
        return duration
    }

    public struct Card: Equatable, Sendable, Identifiable {
        public var key: String
        public var position: Double
        public var duration: Double
        public var updatedAt: Date

        public var id: String { key }
        public var url: URL? { ResumeStore.url(for: key) }
        public var title: String { ResumeStore.title(for: key) }
        public var remaining: Double { max(0, duration - position) }
        public var fraction: Double {
            guard duration > 0 else { return 0 }
            return min(1, max(0, position / duration))
        }

        public init(key: String, position: Double, duration: Double, updatedAt: Date) {
            self.key = key
            self.position = position
            self.duration = duration
            self.updatedAt = updatedAt
        }
    }

    public static func url(for key: String) -> URL? {
        if key.hasPrefix("file:") {
            let body = key.dropFirst("file:".count)
            guard let hash = body.lastIndex(of: "#") else {
                let path = String(body)
                return path.isEmpty ? nil : URL(fileURLWithPath: path)
            }
            let path = String(body[..<hash])
            return path.isEmpty ? nil : URL(fileURLWithPath: path)
        }
        return URL(string: key)
    }

    public static func title(for key: String) -> String {
        guard let url = url(for: key) else { return key }
        let name = url.lastPathComponent
        return name.isEmpty ? url.absoluteString : name
    }

    public func latest(limit: Int) -> [Card] {
        lock.lock()
        let cards = entries.map { key, entry in
            Card(key: key, position: entry.position, duration: entry.duration, updatedAt: entry.updatedAt)
        }
        lock.unlock()
        return cards.sorted { $0.updatedAt > $1.updatedAt }.prefix(max(0, limit)).map { $0 }
    }

    public func fraction(for key: String) -> Double? {
        lock.lock()
        defer { lock.unlock() }
        guard let entry = entries[key], entry.duration > 0 else { return nil }
        return min(1, max(0, entry.position / entry.duration))
    }

    /// Saves a resume point. Positions under 3 seconds, unknown durations, and the last 8 seconds are forgotten.
    public func remember(position: Double, duration: Double, for key: String, now: Date = Date()) {
        lock.lock()
        defer { lock.unlock() }
        let forget = position < 3 || duration <= 0 || position >= duration - 8
        if forget {
            entries.removeValue(forKey: key)
        } else {
            entries[key] = Entry(position: position, duration: duration, updatedAt: now)
        }
        persistLocked()
    }

    public func forget(_ key: String) {
        lock.lock()
        defer { lock.unlock() }
        entries.removeValue(forKey: key)
        persistLocked()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        entries = (try? JSONDecoder().decode([String: Entry].self, from: data)) ?? [:]
    }

    private func persistLocked() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
