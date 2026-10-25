import Foundation

public struct Playlist: Equatable, Sendable {
    public enum EndAction: Equatable, Sendable {
        case play(PlaylistItem)
        case stop
    }

    public private(set) var items: [PlaylistItem]
    public private(set) var currentIndex: Int?
    public private(set) var shuffleEnabled: Bool
    public var repeatMode: RepeatMode
    private var order: [UUID]

    public init(items: [PlaylistItem] = [], currentIndex: Int? = nil, repeatMode: RepeatMode = .off) {
        self.items = items
        self.currentIndex = currentIndex
        self.repeatMode = repeatMode
        self.shuffleEnabled = false
        self.order = []
    }

    public var current: PlaylistItem? {
        guard let currentIndex, items.indices.contains(currentIndex) else { return nil }
        return items[currentIndex]
    }

    public mutating func append(_ newItems: [PlaylistItem]) {
        guard !newItems.isEmpty else { return }
        let wasEmpty = items.isEmpty
        items.append(contentsOf: newItems)
        if wasEmpty { currentIndex = 0 }
        if shuffleEnabled {
            for item in newItems where !order.contains(item.id) {
                order.append(item.id)
            }
        }
    }

    public mutating func select(id: UUID) {
        currentIndex = items.firstIndex { $0.id == id }
    }

    public mutating func remove(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items.remove(at: index)
        order.removeAll { $0 == id }
        guard !items.isEmpty else {
            currentIndex = nil
            return
        }
        if let currentIndex {
            if index < currentIndex {
                self.currentIndex = currentIndex - 1
            } else if index == currentIndex {
                self.currentIndex = min(index, items.count - 1)
            }
        }
    }

    public mutating func move(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        guard !offsets.isEmpty else { return }
        let currentID = current?.id
        let moving = offsets.sorted().map { items[$0] }
        let prefix = offsets.filter { $0 < destination }.count
        for index in offsets.sorted(by: >) {
            items.remove(at: index)
        }
        let insertAt = max(0, min(items.count, destination - prefix))
        items.insert(contentsOf: moving, at: insertAt)
        if let currentID {
            currentIndex = items.firstIndex { $0.id == currentID }
        }
        if shuffleEnabled { syncOrder() }
    }

    public mutating func setShuffle(_ enabled: Bool, using generator: inout some RandomNumberGenerator) {
        shuffleEnabled = enabled
        guard enabled else {
            order = []
            return
        }
        order = items.map(\.id)
        guard order.count > 1 else { return }
        for index in stride(from: order.count - 1, through: 1, by: -1) {
            let swap = Int(generator.next() % UInt64(index + 1))
            order.swapAt(index, swap)
        }
    }

    public mutating func setShuffle(_ enabled: Bool) {
        var generator = SystemRandomNumberGenerator()
        setShuffle(enabled, using: &generator)
    }

    /// Auto-advance when the current file reaches the end.
    public mutating func afterEndOfFile() -> EndAction {
        guard !items.isEmpty else {
            currentIndex = nil
            return .stop
        }
        if repeatMode == .one, let current {
            return .play(current)
        }
        guard let next = step(by: 1, wrap: repeatMode == .all) else { return .stop }
        return .play(next)
    }

    /// Manual next/previous. Repeat-one does not stick. Returns nil if playback should stay put.
    public mutating func skipped(by delta: Int) -> PlaylistItem? {
        guard delta != 0 else { return current }
        return step(by: delta, wrap: repeatMode == .all)
    }

    public func m3uText() -> String {
        var lines = ["#EXTM3U"]
        for item in items {
            lines.append("#EXTINF:-1,\(item.title)")
            lines.append(item.isNetwork ? item.url.absoluteString : item.url.path)
        }
        return lines.joined(separator: "\n") + "\n"
    }

    public static func parseM3U(_ text: String, relativeTo baseDirectory: URL?) -> [PlaylistItem] {
        var items: [PlaylistItem] = []
        var pendingTitle: String?
        for raw in text.split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }
            if line.hasPrefix("#EXTINF") {
                pendingTitle = line.split(separator: ",", maxSplits: 1).dropFirst().last.map(String.init)
                continue
            }
            if line.hasPrefix("#") { continue }
            let url = resolve(line, relativeTo: baseDirectory)
            items.append(PlaylistItem(url: url, title: pendingTitle))
            pendingTitle = nil
        }
        return items
    }

    private mutating func step(by delta: Int, wrap: Bool) -> PlaylistItem? {
        let sequence = playOrder()
        guard !sequence.isEmpty else { return nil }
        let currentID = current?.id
        let position = currentID.flatMap { id in sequence.firstIndex(of: id) } ?? (delta > 0 ? -1 : 0)
        var nextPosition = position + delta
        if wrap {
            nextPosition = (nextPosition % sequence.count + sequence.count) % sequence.count
        } else if nextPosition < 0 || nextPosition >= sequence.count {
            return nil
        }
        let id = sequence[nextPosition]
        currentIndex = items.firstIndex { $0.id == id }
        return current
    }

    private func playOrder() -> [UUID] {
        if shuffleEnabled, order.count == items.count, Set(order) == Set(items.map(\.id)) {
            return order
        }
        return items.map(\.id)
    }

    private mutating func syncOrder() {
        let ids = items.map(\.id)
        order.removeAll { !ids.contains($0) }
        for id in ids where !order.contains(id) {
            order.append(id)
        }
    }

    private static func resolve(_ line: String, relativeTo baseDirectory: URL?) -> URL {
        if line.contains("://"), let url = URL(string: line) { return url }
        if line.hasPrefix("/") { return URL(fileURLWithPath: line) }
        if line.hasPrefix("~") {
            let expanded = (line as NSString).expandingTildeInPath
            return URL(fileURLWithPath: expanded)
        }
        if let baseDirectory {
            return baseDirectory.appendingPathComponent(line)
        }
        return URL(fileURLWithPath: line)
    }
}

public enum RepeatMode: String, Codable, Equatable, Sendable {
    case off
    case one
    case all
}
