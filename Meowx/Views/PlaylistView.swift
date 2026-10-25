import AppKit
import MeowxCore
import SwiftUI

struct PlaylistView: View {
    var model: PlayerModel
    var posters: Bool
    @State private var query = ""
    @State private var selection: UUID?

    private var rows: [PlaylistItem] {
        PlaylistQuery.filter(model.playlist.items, query: query)
    }

    private var canReorder: Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: Theme.s8) {
            TextField("Search", text: $query)
                .textFieldStyle(.roundedBorder)
                .font(Theme.body)
                .onExitCommand { model.setPlaylistOpen(false) }
            List(selection: $selection) {
                ForEach(rows) { item in
                    row(item)
                        .tag(item.id)
                        .contextMenu {
                            Button("Play") { model.play(id: item.id) }
                            if item.url.isFileURL {
                                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
                            }
                            Button("Remove", role: .destructive) { model.remove(id: item.id) }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button("Remove", role: .destructive) { model.remove(id: item.id) }
                        }
                }
                .onMove { offsets, index in
                    guard canReorder else { return }
                    model.move(from: offsets, to: index)
                }
                .onDelete { offsets in
                    offsets.map { rows[$0].id }.forEach { model.remove(id: $0) }
                }
            }
            .scrollContentBackground(.hidden)
            .onDeleteCommand {
                if let selection { model.remove(id: selection) }
            }
            HStack {
                Button { model.openFiles(playNow: false) } label: { Image(systemName: "plus") }
                    .shortcutTip("addToPlaylist", title: "Add to playlist")
                Button { model.toggleShuffle() } label: { Image(systemName: "shuffle") }
                    .foregroundStyle(model.playlist.shuffleEnabled ? Theme.accent : Theme.secondary)
                    .shortcutTip("shuffle")
                Button { model.cycleRepeat() } label: {
                    Image(systemName: model.playlist.repeatMode == .one ? "repeat.1" : "repeat")
                }
                .foregroundStyle(model.playlist.repeatMode == .off ? Theme.secondary : Theme.accent)
                .shortcutTip("repeat", title: "Repeat: \(repeatName)")
                Spacer()
                Button { model.savePlaylist() } label: { Image(systemName: "square.and.arrow.down") }
                    .help("Save playlist")
                    .accessibilityLabel("Save playlist")
                    .disabled(model.playlist.items.isEmpty)
            }
            .buttonStyle(MeowxIconButtonStyle()).meowxFocusRing()
        }
        .padding(Theme.s12)
        .onExitCommand { model.setPlaylistOpen(false) }
        .onKeyPress(.escape) {
            model.setPlaylistOpen(false)
            return .handled
        }
    }

    private func row(_ item: PlaylistItem) -> some View {
        let current = item.id == model.playlist.current?.id
        return Button { model.play(id: item.id) } label: {
            HStack(spacing: Theme.s8) {
                PlaylistThumb(url: item.url, enabled: posters)
                VStack(alignment: .leading, spacing: Theme.s4) {
                    HStack(spacing: Theme.s4) {
                        if current {
                            Image(systemName: "play.fill")
                                .font(Theme.caption)
                                .foregroundStyle(Theme.accent)
                                .accessibilityLabel("Now playing")
                        }
                        Text(item.title)
                            .font(current ? Theme.bodyStrong : Theme.body)
                            .foregroundStyle(Theme.primary)
                            .lineLimit(2)
                    }
                    Text(durationText(item))
                        .font(Theme.digits)
                        .foregroundStyle(Theme.secondary)
                    Capsule()
                        .fill(Theme.inkFaint)
                        .frame(height: Theme.progressHeight)
                        .overlay(alignment: .leading) {
                            GeometryReader { proxy in
                                Capsule()
                                    .fill(current ? Theme.accent : Theme.inkSecondary)
                                    .frame(width: proxy.size.width * model.resumeFraction(for: item), height: proxy.size.height)
                            }
                        }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(item.url.isFileURL ? item.url.path : item.url.absoluteString)
        .accessibilityLabel(item.title)
    }

    private func durationText(_ item: PlaylistItem) -> String {
        guard let seconds = model.rowDuration(item), seconds > 0 else { return "—" }
        return TimeFormat.string(seconds)
    }

    private var repeatName: String {
        switch model.playlist.repeatMode {
        case .off: return "off"
        case .all: return "all"
        case .one: return "one"
        }
    }
}

private struct PlaylistThumb: View {
    var url: URL
    var enabled: Bool
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            Theme.inkFaint
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "film")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.inkSecondary)
            }
        }
        .frame(width: Theme.s32 * 2, height: Theme.s32 + Theme.s4)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
        .task(id: enabled) {
            guard enabled, image == nil, url.isFileURL else { return }
            ThumbnailService.shared.cachedPoster(for: url) { image = $0 }
        }
    }
}
