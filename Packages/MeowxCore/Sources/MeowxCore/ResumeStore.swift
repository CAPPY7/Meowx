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
