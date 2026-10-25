import Foundation

public struct PlaylistItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var url: URL
    public var title: String
    public var isNetwork: Bool

    public init(id: UUID = UUID(), url: URL, title: String? = nil) {
        self.id = id
        self.url = url
        let fallback = url.isFileURL ? url.lastPathComponent : url.absoluteString
        self.title = title?.isEmpty == false ? title! : fallback
        self.isNetwork = !url.isFileURL
    }
}
