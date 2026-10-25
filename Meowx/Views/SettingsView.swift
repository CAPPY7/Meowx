import AppKit
import MeowxCore
import SwiftUI

struct SettingsView: View {
    @State private var model = PlayerModel.shared

    var body: some View {
        Form {
            Toggle("Hardware decoding", isOn: binding(\.hardwareDecoding))
            Toggle("Hide title bar and controls while playing", isOn: binding(\.hideChromeWhilePlaying))
            Toggle("Click the video to play or pause", isOn: binding(\.clickToPause))
            Toggle("Scroll wheel changes volume", isOn: binding(\.scrollAdjustsVolume))
            Toggle("Horizontal scroll seeks", isOn: binding(\.scrollSeeks))
            LabeledContent("Hide after") {
                VStack(alignment: .trailing) {
                    Slider(value: binding(\.chromeHideDelay), in: 1...10, step: 0.5)
                    Text("\(model.settings.chromeHideDelay, specifier: "%.1f") seconds")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            TextField("Subtitle languages", text: binding(\.subtitleLanguage))
                .help("Comma-separated codes, for example en,eng")
            TextField("Audio languages", text: binding(\.audioLanguage))
            LabeledContent("Cache") {
                VStack(alignment: .trailing) {
                    Slider(
                        value: Binding(
                            get: { Double(model.settings.cacheMegabytes) },
                            set: { value in model.updateSettings { $0.cacheMegabytes = Int(value) } }
                        ),
                        in: 64...2048,
                        step: 64
                    )
                    Text("\(model.settings.cacheMegabytes) MB. Used the next time Meowx opens.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            LabeledContent("Screenshots") {
                HStack {
                    Text(model.settings.resolvedScreenshotFolder.path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)
                    Button("Choose…") { chooseFolder() }
                    Picker("Format", selection: binding(\.screenshotFormat)) {
                        Text("PNG").tag(ScreenshotFormat.png)
                        Text("JPEG").tag(ScreenshotFormat.jpg)
                    }
                    .labelsHidden()
                    .frame(width: 90)
                }
            }
            TextField("Subtitle font", text: binding(\.subtitleFont))
            LabeledContent("Subtitle size") {
                Slider(value: binding(\.subtitleSize), in: 18...96, step: 1)
            }
            LabeledContent("Subtitle position") {
                Slider(value: binding(\.subtitlePosition), in: 0...100, step: 1)
            }
            TextField("Subtitle color", text: binding(\.subtitleColorHex))
                .help("#RRGGBB")
            SecureField("OpenSubtitles API key", text: binding(\.openSubtitlesAPIKey))
            Text("The key stays on this Mac. Online search is off until you add one.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Reset to defaults", role: .destructive) { model.resetSettings() }
        }
        .formStyle(.grouped)
        .frame(width: 560)
        .padding(20)
    }

    private func binding(_ keyPath: WritableKeyPath<PlayerSettings, String>) -> Binding<String> {
        Binding(
            get: { model.settings[keyPath: keyPath] },
            set: { value in model.updateSettings { $0[keyPath: keyPath] = value } }
        )
    }

    private func binding(_ keyPath: WritableKeyPath<PlayerSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { model.settings[keyPath: keyPath] },
            set: { value in model.updateSettings { $0[keyPath: keyPath] = value } }
        )
    }

    private func binding(_ keyPath: WritableKeyPath<PlayerSettings, Double>) -> Binding<Double> {
        Binding(
            get: { model.settings[keyPath: keyPath] },
            set: { value in model.updateSettings { $0[keyPath: keyPath] = value } }
        )
    }

    private func binding(_ keyPath: WritableKeyPath<PlayerSettings, ScreenshotFormat>) -> Binding<ScreenshotFormat> {
        Binding(
            get: { model.settings[keyPath: keyPath] },
            set: { value in model.updateSettings { $0[keyPath: keyPath] = value } }
        )
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Choose"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        model.updateSettings { $0.screenshotFolder = url.path }
    }
}

struct URLSheet: View {
    var model: PlayerModel
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Open URL")
                .font(.title3.weight(.semibold))
            TextField("https://, rtsp://, or a file path", text: $text)
                .textFieldStyle(.roundedBorder)
                .onSubmit { model.openURL(text) }
            if model.ytdlpPath == nil {
                Text("YouTube and similar sites need yt-dlp installed separately. Meowx does not bundle it.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Text("yt-dlp is installed, so site links can open when the hook is in the app.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                Button("Cancel") { model.urlPrompt = false }
                Button("Open") { model.openURL(text) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 460)
    }
}

struct TimeSheet: View {
    var model: PlayerModel
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Go to Time")
                .font(.title3.weight(.semibold))
            TextField("90, 1:23, or 1:02:03", text: $text)
                .textFieldStyle(.roundedBorder)
                .onSubmit { model.jumpToTime(text) }
            HStack {
                Spacer()
                Button("Cancel") { model.timePrompt = false }
                Button("Go") { model.jumpToTime(text) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 360)
    }
}

struct ShortcutSheet: View {
    private let rows: [(String, String)] = [
        ("Space", "Play or pause"),
        ("Left / Right", "Seek 5 seconds"),
        ("Shift + Left / Right", "Seek 30 seconds"),
        ("Command + Left / Right", "Previous or next"),
        ("Up / Down", "Volume"),
        ("M", "Mute"),
        ("F", "Full screen"),
        ("S", "Cycle subtitles"),
        ("A", "Cycle audio"),
        ("[ / ]", "Speed down or up"),
        ("\\", "Reset speed"),
        (", / .", "Previous or next frame"),
        ("I", "Stats"),
        ("P", "Picture in Picture"),
        ("Command + O", "Open file"),
        ("Command + U", "Open URL"),
        ("Command + Shift + S", "Screenshot")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Keyboard shortcuts")
                .font(.title3.weight(.semibold))
            ScrollView {
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                    ForEach(rows, id: \.0) { row in
                        GridRow {
                            Text(row.0).font(.callout.monospaced())
                            Text(row.1).font(.callout)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                Spacer()
                Button("Close") { PlayerModel.shared.shortcutPrompt = false }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(width: 460, height: 420)
    }
}

struct SubtitleSearchSheet: View {
    var model: PlayerModel
    @State private var language = ""
    @State private var hits: [SubtitleHit] = []
    @State private var working = false
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Online subtitles")
                .font(.title3.weight(.semibold))
            TextField("Language code", text: $language)
                .textFieldStyle(.roundedBorder)
            if let message {
                Text(message).font(.callout).foregroundStyle(.secondary)
            }
            List(hits) { hit in
                Button {
                    Task { await download(hit) }
                } label: {
                    VStack(alignment: .leading) {
                        Text(hit.title).lineLimit(1)
                        Text(hit.language.uppercased()).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .frame(minHeight: 180)
            HStack {
                Button("Close") { model.searchOpen = false }
                Spacer()
                Button(working ? "Searching…" : "Search") { Task { await search() } }
                    .disabled(working)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 480, height: 420)
        .onAppear {
            if language.isEmpty {
                language = model.settings.subtitleLanguage.split(separator: ",").first.map(String.init) ?? "en"
            }
        }
    }

    private func search() async {
        working = true
        message = nil
        do {
            hits = try await model.searchSubtitles(language: language)
            message = hits.isEmpty ? "No subtitles found." : nil
        } catch {
            message = error.localizedDescription
        }
        working = false
    }

    private func download(_ hit: SubtitleHit) async {
        working = true
        do {
            try await model.useSubtitle(hit)
        } catch {
            message = error.localizedDescription
        }
        working = false
    }
}

struct StatsOverlay: View {
    var model: PlayerModel

    var body: some View {
        VStack {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    stat("Decoder", model.hwdec.isEmpty ? "software" : "HW · \(model.hwdec)")
                    stat("Video", videoLine)
                    stat("Audio", model.audioCodec.isEmpty ? "—" : model.audioCodec)
                    stat("Frames", String(format: "%.3g fps · %d dropped", model.fps, model.droppedFrames))
                    stat("Bitrate", bitrate)
                    stat("Cache", String(format: "%.1f s", model.cacheSeconds))
                }
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white)
                .padding(10)
                .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 8))
                Spacer()
            }
            Spacer()
        }
        .padding(12)
        .allowsHitTesting(false)
    }

    private var videoLine: String {
        let size = model.videoWidth > 0 ? "\(model.videoWidth)×\(model.videoHeight)" : "—"
        let codec = model.videoCodec.isEmpty ? "" : " \(model.videoCodec)"
        return size + codec
    }

    private var bitrate: String {
        guard model.videoBitrate > 0 else { return "—" }
        return String(format: "%.2f Mb/s", model.videoBitrate / 1_000_000)
    }

    private func stat(_ name: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            Text(name).frame(width: 64, alignment: .leading).foregroundStyle(.white.opacity(0.6))
            Text(value)
        }
    }
}
