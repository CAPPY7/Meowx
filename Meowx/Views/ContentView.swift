import AppKit
import MeowxCore
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var model = PlayerModel.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var playlistDrawn: Bool {
        PlaylistPanel.visible(
            open: model.playlistShown,
            chromeVisible: model.chromeShown,
            pointerInside: model.playlistHovered
        )
    }

    var body: some View {
        stage
            .frame(minWidth: Theme.windowMinWidth, minHeight: Theme.windowMinHeight)
            .preferredColorScheme(.dark)
            .background(WindowChrome(shown: model.chromeShown))
            .onAppear { model.start() }
        .onDrop(of: [.fileURL, .url], isTargeted: $model.dropTargeted, perform: drop)
        .sheet(isPresented: $model.urlPrompt) { URLSheet(model: model) }
        .sheet(isPresented: $model.timePrompt) { TimeSheet(model: model) }
        .sheet(isPresented: $model.shortcutPrompt) { ShortcutSheet() }
        .sheet(isPresented: $model.searchOpen) { SubtitleSearchSheet(model: model) }
        .alert("Can't play this", isPresented: errorPresented) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .alert("Playback engine", isPresented: enginePresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.engineError ?? "")
        }
    }

    private var stage: some View {
        ZStack {
            Theme.videoBlack
            VideoHost()
                .opacity(model.showsVideo ? 1 : 0)
            if model.playlist.current == nil {
                emptyState
            } else if !model.showsVideo {
                audioStage.allowsHitTesting(false)
            }
            if model.opening || model.buffering {
                loading.allowsHitTesting(false)
            }
            if let status = model.statusText {
                statusBadge(status)
            }
            if model.statsVisible {
                StatsOverlay(model: model).allowsHitTesting(false)
            }
            if model.dropTargeted {
                dropOverlay
            }
        }
        .overlay(alignment: .top) {
            topBar
                .opacity(model.chromeShown ? 1 : 0)
                .allowsHitTesting(model.chromeShown)
                .animation(Theme.fade(reduceMotion), value: model.chromeShown)
        }
        .overlay(alignment: .bottom) {
            controls
                .opacity(model.chromeShown ? 1 : 0)
                .allowsHitTesting(model.chromeShown)
                .animation(Theme.fade(reduceMotion), value: model.chromeShown)
        }
        .overlay(alignment: .topTrailing) {
            if model.pictureOpen {
                PicturePanel(model: model)
                    .padding(.top, Theme.pictureInset)
                    .padding(.trailing, Theme.s16 + (playlistDrawn ? Theme.playlistWidth + Theme.s16 : 0))
            }
        }
        .overlay(alignment: .trailing) {
            PlaylistView(model: model, posters: playlistDrawn)
                .frame(width: Theme.playlistWidth)
                .meowxSurface(Theme.radiusLarge)
                .padding(Theme.s16)
                .offset(x: playlistDrawn ? 0 : Theme.playlistWidth + Theme.s16)
                .opacity(playlistDrawn ? 1 : 0)
                .allowsHitTesting(playlistDrawn)
                .animation(Theme.spring(reduceMotion), value: playlistDrawn)
                .onHover { hovering in
                    model.playlistHovered = hovering
                }
        }
        .background(Theme.videoBlack)
        .onContinuousHover { phase in
            if case .active = phase { model.poke() }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.s12) {
            MeowxMark()
                .foregroundStyle(Theme.inkSoft)
            Text("Drop a video, album, or folder")
                .font(Theme.title)
                .foregroundStyle(Theme.ink)
            Text(model.ytdlpPath == nil
                 ? "Open a file or a stream. Install yt-dlp if you want site links."
                 : "Open a file, a stream, or a link yt-dlp can read.")
                .font(Theme.body)
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: Theme.copyWidth)
            Button("Open…") { model.openFiles(playNow: true) }
                .keyboardShortcut(.defaultAction)
                .meowxHit()
        }
        .padding(Theme.s24)
    }

    private var audioStage: some View {
        VStack(spacing: Theme.s16) {
            artwork
            Text(model.displayTitle)
                .font(Theme.title)
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            if !model.artist.isEmpty {
                Text(model.artist)
                    .font(Theme.body)
                    .foregroundStyle(Theme.inkSecondary)
            }
        }
        .padding(Theme.s32)
    }

    @ViewBuilder private var artwork: some View {
        if let artwork = model.artwork {
            Image(nsImage: artwork)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: Theme.artwork, maxHeight: Theme.artwork)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                .fill(Theme.inkFaint)
                .frame(width: Theme.placeholderArt, height: Theme.placeholderArt)
                .overlay {
                    Image(systemName: "music.note")
                        .font(Theme.symbol)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Theme.inkSoft)
                }
        }
    }

    private var loading: some View {
        VStack(spacing: Theme.s8) {
            ProgressView().controlSize(.large)
            Text(model.buffering ? "Buffering \(Int(model.cacheSeconds))s" : "Opening")
                .font(Theme.body)
                .foregroundStyle(Theme.ink)
        }
        .padding(Theme.s16)
        .background(Theme.scrim, in: RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
    }

    private func statusBadge(_ text: String) -> some View {
        VStack {
            VStack(spacing: Theme.s8) {
                Text(text)
                    .font(Theme.bodyStrong)
                if let progress = model.statusProgress {
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.inkTrack)
                        Capsule().fill(Theme.ink).frame(width: Theme.progressWidth * progress)
                    }
                    .frame(width: Theme.progressWidth, height: Theme.progressHeight)
                }
            }
            .padding(.horizontal, Theme.s12)
            .padding(.vertical, Theme.s8)
            .background(Theme.scrim, in: RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
            .foregroundStyle(Theme.ink)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.s24)
        .allowsHitTesting(false)
    }

    private var controls: some View {
        ControlsView(model: model)
            .padding(Theme.s12)
            .meowxSurface(Theme.radiusMedium)
            .padding(Theme.s12)
            .onHover { hovering in
                model.controlsHovered = hovering
                model.poke()
            }
    }

    private var topBar: some View {
        ZStack {
            titlePill
            HStack(spacing: Theme.s8) {
                Theme.clear
                    .frame(width: model.fullscreen ? 0 : model.trafficInset)
                    .accessibilityHidden(true)
                Spacer(minLength: 0)
                Button(action: model.togglePlaylist) {
                    Image(systemName: model.playlistShown ? "list.bullet.rectangle.fill" : "list.bullet.rectangle")
                }
                .shortcutTip("showPlaylist")
                Button { model.openFiles(playNow: true) } label: { Image(systemName: "folder") }
                    .shortcutTip("open")
                Button { model.urlPrompt = true } label: { Image(systemName: "link") }
                    .shortcutTip("openURL")
                moreMenu
            }
            .buttonStyle(MeowxIconButtonStyle())
            .foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, Theme.s16)
        .padding(.top, Theme.s8)
        .onHover { hovering in
            model.topHovered = hovering
            model.poke()
        }
    }

    private var titlePill: some View {
        VStack(spacing: Theme.s4) {
            Text(model.playlist.current == nil ? "Meowx" : model.displayTitle)
                .font(Theme.bodyStrong)
                .lineLimit(1)
            if model.playlist.current != nil, !model.mediaDetail.isEmpty || model.showsHDR {
                HStack(spacing: Theme.s8) {
                    if !model.mediaDetail.isEmpty {
                        Text(model.mediaDetail)
                            .lineLimit(1)
                    }
                    if model.showsHDR {
                        Text("HDR")
                            .font(Theme.captionStrong)
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, Theme.s8)
                            .padding(.vertical, Theme.s4)
                            .background(Theme.magenta, in: Capsule())
                    }
                }
                .font(Theme.caption)
                .foregroundStyle(Theme.inkSecondary)
            }
        }
        .padding(.horizontal, Theme.s16)
        .padding(.vertical, Theme.s8)
        .meowxPill()
        .frame(maxWidth: Theme.copyWidth)
    }

    private var moreMenu: some View {
        Menu {
            Button("Add Subtitle…") { model.openSubtitleFile() }
                .disabled(model.playlist.current == nil)
            Button("Stats") { model.toggleStats() }
            Button("Show in Finder") { model.revealCurrent() }
                .disabled(model.playlist.current?.url.isFileURL != true)
            Button("Keyboard Shortcuts") { model.shortcutPrompt = true }
        } label: {
            Image(systemName: "ellipsis")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .meowxHit()
        .help("More")
        .accessibilityLabel("More")
    }

    private var dropOverlay: some View {
        RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous)
            .strokeBorder(Theme.dropBorder, lineWidth: Theme.hairline)
            .background(Theme.dropScrim, in: RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous))
            .overlay {
                Text("Drop to play")
                    .font(Theme.title)
                    .foregroundStyle(Theme.ink)
            }
            .padding(Theme.s16)
            .allowsHitTesting(false)
    }

    private var errorPresented: Binding<Bool> {
        Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })
    }

    private var enginePresented: Binding<Bool> {
        Binding(get: { model.engineError != nil }, set: { if !$0 { model.engineError = nil } })
    }

    private func drop(_ providers: [NSItemProvider]) -> Bool {
        Task {
            var urls: [URL] = []
            for provider in providers {
                if let url = await loadURL(from: provider) { urls.append(url) }
            }
            guard !urls.isEmpty else { return }
            model.add(urls: urls, playNow: true)
        }
        return true
    }

    private func loadURL(from provider: NSItemProvider) async -> URL? {
        let type = provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
            ? UTType.fileURL.identifier
            : UTType.url.identifier
        return await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: type, options: nil) { item, _ in
                if let url = item as? URL {
                    continuation.resume(returning: url)
                } else if let data = item as? Data, let string = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), let url = URL(string: string) {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

struct VideoHost: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = Theme.nsVideoBlack.cgColor
        PlayerModel.shared.attachMainHost(view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        PlayerModel.shared.attachMainHost(nsView)
    }
}
