import AppKit
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
                    .help("Add to playlist")
                Button { model.toggleShuffle() } label: { Image(systemName: "shuffle") }
                    .foregroundStyle(model.playlist.shuffleEnabled ? Color.accentColor : Color.secondary)
                    .help("Shuffle")
                Button { model.cycleRepeat() } label: {
                    Image(systemName: model.playlist.repeatMode == .one ? "repeat.1" : "repeat")
                }
                .foregroundStyle(model.playlist.repeatMode == .off ? Color.secondary : Color.accentColor)
                .help("Repeat")
                Spacer()
                Button { model.savePlaylist() } label: { Image(systemName: "square.and.arrow.down") }
                    .help("Save playlist")
                    .disabled(model.playlist.items.isEmpty)
            }
            .buttonStyle(.borderless)
            .padding(8)
        }
        .navigationTitle("Playlist")
    }
}
