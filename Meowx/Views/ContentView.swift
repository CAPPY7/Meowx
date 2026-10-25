import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var model = PlayerModel.shared

    var body: some View {
        NavigationSplitView {
            PlaylistView(model: model)
                .navigationSplitViewColumnWidth(min: 220, ideal: 280, max: 420)
        } detail: {
            stage
                .navigationTitle(model.playlist.current == nil ? "Meowx" : model.displayTitle)
                .toolbar { toolbar }
        }
        .frame(minWidth: 780, minHeight: 480)
        .onAppear { model.start() }
        .onDrop(of: [.fileURL, .url], isTargeted: $model.dropTargeted, perform: drop)
        .sheet(isPresented: $model.urlPrompt) { URLSheet(model: model) }
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
            Color.black
            VideoHost()
                .opacity(model.showsVideo ? 1 : 0)
            if model.playlist.current == nil {
                emptyState
            } else if !model.showsVideo {
                audioStage
            }
            if model.opening || model.buffering {
                loading
            }
            if let status = model.statusText {
                statusBadge(status)
            }
            if model.statsVisible {
                StatsOverlay(model: model)
            }
            if model.controlsVisible || model.paused || model.playlist.current == nil {
                controls
            }
            if model.dropTargeted {
                dropOverlay
            }
        }
        .background(Color.black)
        .onContinuousHover { phase in
            if case .active = phase { model.poke() }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "play.rectangle")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.white.opacity(0.85))
            Text("Drop a video, album, or folder")
                .font(.title3.weight(.medium))
                .foregroundStyle(.white)
            Text(model.ytdlpPath == nil
                 ? "Open a file or a stream. Install yt-dlp if you want site links."
                 : "Open a file, a stream, or a link yt-dlp can read.")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            Button("Open…") { model.openFiles(playNow: true) }
                .keyboardShortcut(.defaultAction)
        }
        .padding(24)
    }

    private var audioStage: some View {
        VStack(spacing: 16) {
            artwork
            Text(model.displayTitle)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            if !model.artist.isEmpty {
                Text(model.artist)
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.72))
            }
        }
        .padding(32)
    }

    @ViewBuilder private var artwork: some View {
        if let artwork = model.artwork {
            Image(nsImage: artwork)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 320, maxHeight: 320)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.08))
                .frame(width: 220, height: 220)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 56, weight: .light))
                        .foregroundStyle(.white.opacity(0.8))
                }
        }
    }

    private var loading: some View {
        VStack(spacing: 8) {
            ProgressView().controlSize(.large)
            Text(model.buffering ? "Buffering \(Int(model.cacheSeconds))s" : "Opening")
                .font(.callout)
                .foregroundStyle(.white)
        }
        .padding(16)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
    }

    private func statusBadge(_ text: String) -> some View {
        VStack {
            Text(text)
                .font(.callout.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.black.opacity(0.6), in: Capsule())
                .foregroundStyle(.white)
            Spacer()
        }
        .padding(.top, 16)
        .allowsHitTesting(false)
    }

    private var controls: some View {
        VStack {
            Spacer()
            ControlsView(model: model)
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                .padding(12)
                .onHover { model.controlsHovered = $0 }
        }
    }

    private var dropOverlay: some View {
        RoundedRectangle(cornerRadius: 16)
            .strokeBorder(.white.opacity(0.85), lineWidth: 2)
            .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                Text("Drop to play")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.white)
            }
            .padding(16)
            .allowsHitTesting(false)
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItemGroup {
            Button { model.openFiles(playNow: true) } label: { Image(systemName: "folder") }
                .help("Open")
            Button { model.urlPrompt = true } label: { Image(systemName: "link") }
                .help("Open URL")
            Button { model.openSubtitleFile() } label: { Image(systemName: "captions.bubble") }
                .help("Add subtitle")
                .disabled(model.playlist.current == nil)
            Button { model.toggleStats() } label: { Image(systemName: "gauge.with.dots.needle.67percent") }
                .help("Stats")
        }
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
        view.layer?.backgroundColor = NSColor.black.cgColor
        PlayerModel.shared.attachMainHost(view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        PlayerModel.shared.attachMainHost(nsView)
    }
}
