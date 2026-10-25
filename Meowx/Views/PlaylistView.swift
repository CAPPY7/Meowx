import AppKit
import MeowxCore
import SwiftUI

struct PlaylistView: View {
    var model: PlayerModel

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(model.playlist.items) { item in
                    Button { model.play(id: item.id) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.callout.weight(item.id == model.playlist.current?.id ? .semibold : .regular))
                                .lineLimit(2)
                                .foregroundStyle(.primary)
                            Text(item.isNetwork ? (item.url.host ?? item.url.absoluteString) : item.url.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(item.url.isFileURL ? item.url.path : item.url.absoluteString)
                    .accessibilityLabel(item.title)
                    .contextMenu {
                        Button("Play") { model.play(id: item.id) }
                        if item.url.isFileURL {
                            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
                        }
                        Button("Remove", role: .destructive) { model.remove(id: item.id) }
                    }
                }
                .onMove { offsets, index in
                    model.move(from: offsets, to: index)
                }
            }
            .onDeleteCommand {
                if let id = model.playlist.current?.id { model.remove(id: id) }
            }
            HStack {
                Button { model.openFiles(playNow: false) } label: { Image(systemName: "plus") }
                    .shortcutTip("addToPlaylist", title: "Add to playlist")
                Button { model.toggleShuffle() } label: { Image(systemName: "shuffle") }
                    .foregroundStyle(model.playlist.shuffleEnabled ? Color.accentColor : Color.secondary)
                    .shortcutTip("shuffle")
                Button { model.cycleRepeat() } label: {
                    Image(systemName: model.playlist.repeatMode == .one ? "repeat.1" : "repeat")
                }
                .foregroundStyle(model.playlist.repeatMode == .off ? Color.secondary : Color.accentColor)
                .shortcutTip("repeat", title: "Repeat: \(repeatName)")
                Spacer()
                Button { model.savePlaylist() } label: { Image(systemName: "square.and.arrow.down") }
                    .help("Save playlist")
                    .accessibilityLabel("Save playlist")
                    .disabled(model.playlist.items.isEmpty)
            }
            .buttonStyle(.borderless)
            .padding(8)
        }
        .navigationTitle("Playlist")
    }

    private var repeatName: String {
        switch model.playlist.repeatMode {
        case .off: return "off"
        case .all: return "all"
        case .one: return "one"
        }
    }
}
