import Foundation

final class AppLog {
    static let shared = AppLog()
    private var lines: [String] = []
    private let lock = NSLock()

    func add(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        lock.lock()
        lines.append(trimmed)
        if lines.count > 200 { lines.removeFirst(lines.count - 200) }
        lock.unlock()
    }

    func recent(limit: Int, includePaths: Bool) -> String {
        lock.lock()
        let tail = lines.suffix(max(0, limit))
        lock.unlock()
        return tail.map { LogPrivacy.redact($0, includePaths: includePaths) }.joined(separator: "\n")
    }
}
