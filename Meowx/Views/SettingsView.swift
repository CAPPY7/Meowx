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
            Toggle("Quit when the window closes", isOn: binding(\.quitWhenWindowCloses))
            Toggle("Resize window to the video when a file opens", isOn: binding(\.resizeToVideoOnOpen))
            LabeledContent("Hide after") {
                VStack(alignment: .trailing) {
                    Slider(value: binding(\.chromeHideDelay), in: 1...10, step: 0.5)
                    Text("\(model.settings.chromeHideDelay, specifier: "%.1f") seconds")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.secondary)
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
                    Text("\(model.settings.cacheMegabytes) MB. Applies now. Backward cache stays at most 128 MB.")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.secondary)
                }
            }
            LabeledContent("Screenshots") {
                HStack {
                    Text(model.settings.resolvedScreenshotFolder.path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(Theme.secondary)
                    Button("Choose…") { chooseFolder() }
                    Picker("Format", selection: binding(\.screenshotFormat)) {
                        Text("PNG").tag(ScreenshotFormat.png)
                        Text("JPEG").tag(ScreenshotFormat.jpg)
                    }
                    .labelsHidden()
                    .frame(width: Theme.volumeWidth)
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
                .font(Theme.caption)
                .foregroundStyle(Theme.secondary)
            Button("Reset to defaults", role: .destructive) { model.resetSettings() }
        }
        .formStyle(.grouped)
        .frame(width: Theme.settingsWidth)
        .padding(Theme.s24)
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
        VStack(alignment: .leading, spacing: Theme.s12) {
            Text("Open URL")
                .font(Theme.title)
            TextField("https://, rtsp://, or a file path", text: $text)
                .textFieldStyle(.roundedBorder)
                .onSubmit { model.openURL(text) }
            if model.ytdlpPath == nil {
                Text("YouTube and similar sites need yt-dlp installed separately. Meowx does not bundle it.")
                    .font(Theme.body)
                    .foregroundStyle(Theme.secondary)
            } else {
                Text("yt-dlp is installed, so site links can open when the hook is in the app.")
                    .font(Theme.body)
                    .foregroundStyle(Theme.secondary)
            }
            HStack {
                Spacer()
                Button("Cancel") { model.urlPrompt = false }
                Button("Open") { model.openURL(text) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Theme.s24)
        .frame(width: Theme.sheetMid)
    }
}

struct TimeSheet: View {
    var model: PlayerModel
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s12) {
            Text("Go to Time")
                .font(Theme.title)
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
        .padding(Theme.s24)
        .frame(width: Theme.sheetNarrow)
    }
}

struct ShortcutSheet: View {
    @State private var query = ""

    private var rows: [ShortcutCommand] {
        let keyed = ShortcutCatalog.all.filter { !$0.token.isEmpty }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return keyed }
        return keyed.filter {
            $0.title.localizedCaseInsensitiveContains(trimmed)
                || $0.display.localizedCaseInsensitiveContains(trimmed)
                || $0.group.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private var grouped: [String: [ShortcutCommand]] {
        Dictionary(grouping: rows, by: \.group)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s12) {
            Text("Keyboard shortcuts")
                .font(Theme.title)
            TextField("Search", text: $query)
                .textFieldStyle(.roundedBorder)
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.s16) {
                    ForEach(grouped.keys.sorted(), id: \.self) { group in
                        Text(group)
                            .font(Theme.bodyStrong)
                        Grid(alignment: .leading, horizontalSpacing: Theme.s24, verticalSpacing: Theme.s8) {
                            ForEach(grouped[group] ?? []) { row in
                                GridRow {
                                    Text(row.display).font(Theme.bodyDigits)
                                    Text(row.title).font(Theme.body)
                                }
                            }
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
        .padding(Theme.s24)
        .frame(width: Theme.sheetMid, height: Theme.sheetMid)
    }
}

struct SubtitleSearchSheet: View {
    var model: PlayerModel
    @State private var language = ""
    @State private var hits: [SubtitleHit] = []
    @State private var working = false
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s12) {
            Text("Online subtitles")
                .font(Theme.title)
            TextField("Language code", text: $language)
                .textFieldStyle(.roundedBorder)
            if let message {
                Text(message).font(Theme.body).foregroundStyle(Theme.secondary)
            }
            List(hits) { hit in
                Button {
                    Task { await download(hit) }
                } label: {
                    VStack(alignment: .leading) {
                        Text(hit.title).lineLimit(1)
                        Text(hit.language.uppercased()).font(Theme.caption).foregroundStyle(Theme.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .frame(minHeight: Theme.listMin)
            HStack {
                Button("Close") { model.searchOpen = false }
                Spacer()
                Button(working ? "Searching…" : "Search") { Task { await search() } }
                    .disabled(working)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Theme.s24)
        .frame(width: Theme.sheetSearchWidth, height: Theme.sheetSearchHeight)
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
                VStack(alignment: .leading, spacing: Theme.s4) {
                    stat("Decoder", model.hwdec.isEmpty ? "software" : "HW · \(model.hwdec)")
                    stat("Video", videoLine)
                    stat("Audio", model.audioCodec.isEmpty ? "—" : model.audioCodec)
                    stat("Frames", String(format: "%.3g fps · %d dropped", model.fps, model.droppedFrames))
                    stat("Bitrate", bitrate)
                    stat("Cache", String(format: "%.1f s", model.cacheSeconds))
                }
                .font(Theme.mono)
                .foregroundStyle(Theme.ink)
                .padding(Theme.s8)
                .background(Theme.scrimStrong, in: RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
                Spacer()
            }
            Spacer()
        }
        .padding(Theme.s12)
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
        HStack(spacing: Theme.s8) {
            Text(name).frame(width: Theme.statsLabel, alignment: .leading).foregroundStyle(Theme.inkTertiary)
            Text(value)
        }
    }
}
