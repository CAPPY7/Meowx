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
            .preferredColorScheme(model.settings.appearance == .dark ? .dark : nil)
            .background(WindowChrome(shown: model.chromeShown))
            .onAppear { model.start() }
        .onDrop(of: [.fileURL, .url], isTargeted: $model.dropTargeted, perform: drop)
        .sheet(isPresented: $model.urlPrompt) { URLSheet(model: model) }
        .sheet(isPresented: $model.timePrompt) { TimeSheet(model: model) }
        .sheet(isPresented: $model.shortcutPrompt) { ShortcutSheet() }
        .sheet(isPresented: $model.searchOpen) { SubtitleSearchSheet(model: model) }
        .sheet(isPresented: $model.infoOpen) { MediaInfoSheet(model: model) }
        .sheet(isPresented: $model.logsOpen) { LogsSheet(model: model) }
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
                HomeView(model: model)
            } else if !model.showsVideo {
                AudioStage(model: model)
            }
            if model.statsVisible {
                StatsOverlay(model: model).allowsHitTesting(false)
            }
            if model.dropTargeted, model.playlist.current != nil {
                dropOverlay
            }
            if model.errorMessage != nil {
                ProblemCard(model: model)
            }
            if let glyph = model.actionGlyph {
                CenterGlyph(glyph: glyph)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .top) {
            if let title = model.openingTitle {
                Text(title)
                    .font(Theme.bodyStrong)
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, Theme.s16)
                    .padding(.vertical, Theme.s8)
                    .meowxPill()
                    .padding(.top, Theme.s16)
                    .padding(.horizontal, Theme.s32)
                    .frame(maxWidth: .infinity)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .animation(Theme.fade(reduceMotion), value: model.openingTitle)
        .overlay(alignment: .topTrailing) {
            PlaylistView(model: model, posters: playlistDrawn)
                .frame(width: Theme.playlistWidth, height: Theme.playlistCard)
                .meowxSurface(Theme.radiusLarge)
                .padding(.top, Theme.playlistTop)
                .padding(.trailing, Theme.s16)
                .offset(x: playlistDrawn ? 0 : Theme.playlistWidth + Theme.s32)
                .opacity(playlistDrawn ? 1 : 0)
                .allowsHitTesting(playlistDrawn)
                .animation(Theme.fade(reduceMotion), value: playlistDrawn)
                .onHover { hovering in
                    model.playlistHovered = hovering
                }
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: Theme.s12) {
                if let status = model.statusText {
                    StatusPill(text: status, progress: model.statusProgress, mark: model.statusMark)
                        .allowsHitTesting(false)
                }
                controls
                    .opacity(model.chromeShown ? 1 : 0)
                    .allowsHitTesting(model.chromeShown)
            }
            .animation(Theme.fade(reduceMotion), value: model.chromeShown)
            .animation(Theme.fade(reduceMotion), value: model.statusText)
        }
        .overlay(alignment: .topLeading) {
            if let offer = model.updateOffer, let url = URL(string: "https://github.com/Cappy7/Meowx/releases/latest") {
                Link(destination: url) {
                    Text("Update \(offer) available")
                        .font(Theme.captionStrong)
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, Theme.s12)
                        .padding(.vertical, Theme.s8)
                        .meowxPill()
                }
                .buttonStyle(.plain)
                .help("Open the latest Meowx release. Nothing is installed for you.")
                .padding(.top, model.chromeShown ? 72 : Theme.s12)
                .padding(.leading, model.fullscreen ? Theme.s16 : model.trafficInset + Theme.s16)
            }
        }
        .overlay(alignment: .topTrailing) {
            if model.pictureOpen {
                PicturePanel(model: model)
                    .padding(.top, Theme.pictureInset + (playlistDrawn ? Theme.playlistCard + Theme.s8 : 0))
                    .padding(.trailing, Theme.s16)
            }
        }
        .background(Theme.videoBlack)
    }

    private var controls: some View {
        ControlsView(model: model)
            .padding(.horizontal, Theme.s24)
            .padding(.bottom, Theme.s24)
            .onHover { hovering in
                model.controlsHovered = hovering
                model.poke()
            }
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

private struct StatusPill: View {
    var text: String
    var progress: Double?
    var mark: StatusMark

    var body: some View {
        HStack(spacing: Theme.s8) {
            Image(systemName: symbol)
                .font(Theme.symbol)
                .symbolRenderingMode(.hierarchical)
            VStack(alignment: .leading, spacing: Theme.s4) {
                Text(text).font(Theme.bodyStrong)
                if let progress {
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.inkTrack)
                        Capsule().fill(Theme.accent).frame(width: Theme.progressWidth * progress)
                    }
                    .frame(width: Theme.progressWidth, height: Theme.progressHeight)
                }
            }
        }
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, Theme.s16)
        .padding(.vertical, Theme.s8)
        .meowxGlass(capsule: true)
    }

    private var symbol: String {
        switch mark {
        case .volume: return "speaker.wave.2.fill"
        case .speed: return "speedometer"
        case .seekForward: return "goforward"
        case .seekBack: return "gobackward"
        case .track: return "captions.bubble"
        case .loop: return "repeat"
        case .generic: return "info.circle"
        }
    }
}

private struct CenterGlyph: View {
    var glyph: ActionGlyph

    var body: some View {
        Image(systemName: symbol)
            .font(Theme.title)
            .foregroundStyle(Theme.ink)
            .frame(width: Theme.playSize + Theme.s16, height: Theme.playSize + Theme.s16)
            .background(Theme.scrim, in: Circle())
    }

    private var symbol: String {
        switch glyph {
        case .play: return "play.fill"
        case .pause: return "pause.fill"
        case .skipBack: return "backward.fill"
        case .skipForward: return "forward.fill"
        case .seekBack: return "gobackward"
        case .seekForward: return "goforward"
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
