import AppKit
import MeowxCore
import SwiftUI

struct SettingsView: View {
    @State private var model = PlayerModel.shared
    @State private var devices: [(id: String, name: String)] = []

    var body: some View {
        TabView {
            general.tabItem { Label("General", systemImage: "gearshape") }
            playback.tabItem { Label("Playback", systemImage: "play.circle") }
            video.tabItem { Label("Video", systemImage: "film") }
            audio.tabItem { Label("Audio", systemImage: "speaker.wave.2") }
            subtitles.tabItem { Label("Subtitles", systemImage: "captions.bubble") }
            shortcuts.tabItem { Label("Shortcuts", systemImage: "keyboard") }
            advanced.tabItem { Label("Advanced", systemImage: "wrench.and.screwdriver") }
        }
        .frame(width: Theme.settingsWidth, height: Theme.settingsHeight)
        .preferredColorScheme(model.settings.appearance == .dark ? .dark : nil)
        .onAppear { refreshDevices() }
    }

    private var general: some View {
        Form {
            Picker("Appearance", selection: binding(\.appearance)) {
                Text("Dark").tag(AppAppearance.dark)
                Text("Match System").tag(AppAppearance.system)
            }
            Toggle("Hide title bar and controls while playing", isOn: binding(\.hideChromeWhilePlaying))
            LabeledContent("Hide after") {
                VStack(alignment: .trailing) {
                    Slider(value: binding(\.chromeHideDelay), in: 1...10, step: 0.5)
                    Text("\(model.settings.chromeHideDelay, specifier: "%.1f") seconds")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.secondary)
                }
            }
            Toggle("Quit when the window closes", isOn: binding(\.quitWhenWindowCloses))
            Toggle("Resize window to the video when a file opens", isOn: binding(\.resizeToVideoOnOpen))
            Button("Set as Default Player") { model.makeDefaultPlayer() }
            Text("Checking for updates is not built yet.")
                .font(Theme.caption)
                .foregroundStyle(Theme.secondary)
        }
        .formStyle(.grouped)
    }

    private var playback: some View {
        Form {
            Toggle("Resume where you left off", isOn: binding(\.resumeOnOpen))
            Toggle("Play the next file", isOn: binding(\.playNext))
            Picker("When the playlist ends", selection: binding(\.endBehavior)) {
                Text("Stop").tag(RepeatMode.off)
                Text("Repeat playlist").tag(RepeatMode.all)
                Text("Repeat this file").tag(RepeatMode.one)
            }
            Toggle("Click the video to play or pause", isOn: binding(\.clickToPause))
            Toggle("Double-click the sides to jump", isOn: binding(\.doubleClickSidesSeek))
            Toggle("Scroll wheel changes volume", isOn: binding(\.scrollAdjustsVolume))
            Toggle("Horizontal scroll seeks", isOn: binding(\.scrollSeeks))
            Picker("Speed step", selection: binding(\.speedStep)) {
                Text("Preset ladder").tag(SpeedStep.ladder)
                Text("0.1×").tag(SpeedStep.tenth)
                Text("0.25×").tag(SpeedStep.quarter)
            }
            Stepper(value: binding(\.seekShort), in: 1...120, step: 1) {
                Text("Short seek \(Int(model.settings.seekShort)) s")
            }
            Stepper(value: binding(\.seekMedium), in: 1...120, step: 1) {
                Text("Medium seek \(Int(model.settings.seekMedium)) s")
            }
            Stepper(value: binding(\.seekLong), in: 1...120, step: 1) {
                Text("Long seek \(Int(model.settings.seekLong)) s")
            }
            note("Arrow keys use the short step. Shift uses the long step. The side buttons and a side double-click use the medium step. Applies now.")
        }
        .formStyle(.grouped)
    }

    private var video: some View {
        Form {
            Toggle("Hardware decoding", isOn: binding(\.hardwareDecoding))
            Picker("HDR tone mapping", selection: binding(\.toneMapping)) {
                ForEach(ToneMap.allCases, id: \.self) { choice in
                    Text(choice.label).tag(choice)
                }
            }
            Picker("Default aspect", selection: binding(\.defaultAspect)) {
                ForEach(AspectCycle.presets, id: \.self) { preset in
                    Text(AspectCycle.label(preset)).tag(preset)
                }
            }
            Toggle("Deinterlace new files", isOn: binding(\.deinterlaceOnOpen))
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
            Toggle("Include subtitles in screenshots", isOn: binding(\.screenshotWithSubtitles))
            note("Hardware decoding, tone mapping, aspect, and deinterlace apply to the current file now.")
        }
        .formStyle(.grouped)
    }

    private var audio: some View {
        Form {
            Picker("Output", selection: binding(\.audioDevice)) {
                Text("Auto").tag("auto")
                ForEach(devices, id: \.id) { device in
                    Text(device.name).tag(device.id)
                }
            }
            Button("Refresh devices") { refreshDevices() }
            Toggle("Normalize loudness", isOn: binding(\.loudnessNormalize))
            Toggle("Compressor", isOn: binding(\.audioCompressor))
            TextField("Preferred audio languages", text: binding(\.audioLanguage))
                .help("Comma-separated codes, for example ja,en")
            Toggle("Remember volume", isOn: binding(\.rememberVolume))
            note("The device, normalization, compressor, and languages apply now. An equalizer is not built yet.")
        }
        .formStyle(.grouped)
    }

    private var subtitles: some View {
        Form {
            TextField("Font", text: binding(\.subtitleFont))
                .help("Empty uses the mpv font")
            LabeledContent("Size") {
                Slider(value: binding(\.subtitleSize), in: 18...96, step: 1)
            }
            TextField("Color", text: binding(\.subtitleColorHex))
                .help("#RRGGBB")
            LabeledContent("Outline") {
                Slider(value: binding(\.subtitleOutline), in: 0...8, step: 0.5)
            }
            LabeledContent("Position") {
                Slider(value: binding(\.subtitlePosition), in: 0...100, step: 1)
            }
            LabeledContent("Default delay") {
                Slider(value: binding(\.subtitleDelayDefault), in: -5...5, step: 0.1)
            }
            TextField("Preferred languages", text: binding(\.subtitleLanguage))
                .help("Comma-separated codes, for example en,eng")
            Picker("Encoding", selection: binding(\.subtitleEncoding)) {
                Text("Auto").tag("auto")
                Text("UTF-8").tag("utf-8")
                Text("UTF-16").tag("utf-16")
                Text("Shift JIS").tag("shift_jis")
                Text("Windows-1252").tag("cp1252")
            }
            note("Font, size, color, outline, position, delay, language, and encoding apply now.")
            DisclosureGroup("Online search (optional)") {
                SecureField("OpenSubtitles API key", text: binding(\.openSubtitlesAPIKey))
                Text("The key stays on this Mac. Search stays off until you add one.")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondary)
                if let url = URL(string: "https://www.opensubtitles.com/en/consumers") {
                    Link("How to get a key", destination: url)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var shortcuts: some View {
        ShortcutSettings(model: model)
    }

    private var advanced: some View {
        Form {
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
            Toggle("Verbose mpv log", isOn: binding(\.verboseLog))
            note("Applies now.")
            Button("Copy diagnostics") { model.copyDiagnostics() }
            Button("Reset all settings", role: .destructive) { model.resetSettings() }
        }
        .formStyle(.grouped)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(Theme.caption)
            .foregroundStyle(Theme.secondary)
    }

    private func refreshDevices() {
        let found = model.audioOutputs()
        devices = found.filter { $0.id != "auto" }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<PlayerSettings, Value>) -> Binding<Value> {
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

struct ShortcutSettings: View {
    var model: PlayerModel
    @State private var query = ""

    private var rows: [ShortcutCommand] {
        let keyed = ShortcutCatalog.all
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return keyed }
        return keyed.filter {
            $0.title.localizedCaseInsensitiveContains(trimmed)
                || $0.group.localizedCaseInsensitiveContains(trimmed)
                || ShortcutMap.resolved($0, overrides: model.settings.shortcutOverrides).display.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s8) {
            TextField("Search shortcuts", text: $query)
                .textFieldStyle(.roundedBorder)
            if let conflict = model.shortcutConflict {
                Text(conflict)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.warning)
            }
            if model.shortcutCaptureID != nil {
                Text("Press the new key. Esc cancels.")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondary)
            }
            List(rows) { row in
                HStack {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(row.title).font(Theme.body)
                        Text(row.group).font(Theme.caption).foregroundStyle(Theme.secondary)
                    }
                    Spacer()
                    let shown = ShortcutMap.resolved(row, overrides: model.settings.shortcutOverrides)
                    Button(model.shortcutCaptureID == row.id ? "Press a key" : (shown.display.isEmpty ? "None" : shown.display)) {
                        model.beginShortcutCapture(row.id)
                    }
                }
            }
            HStack {
                Button("Restore defaults") {
                    model.updateSettings { $0.shortcutOverrides = [:] }
                    model.shortcutConflict = nil
                    model.shortcutCaptureID = nil
                }
                Spacer()
            }
        }
        .padding(Theme.s16)
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
        let keyed = ShortcutCatalog.all.filter { !$0.token.isEmpty || PlayerModel.shared.settings.shortcutOverrides[$0.id] != nil }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return keyed }
        return keyed.filter {
            let shown = ShortcutMap.resolved($0, overrides: PlayerModel.shared.settings.shortcutOverrides)
            return shown.title.localizedCaseInsensitiveContains(trimmed)
                || shown.display.localizedCaseInsensitiveContains(trimmed)
                || shown.group.localizedCaseInsensitiveContains(trimmed)
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
                                let shown = ShortcutMap.resolved(row, overrides: PlayerModel.shared.settings.shortcutOverrides)
                                GridRow {
                                    Text(shown.display.isEmpty ? "—" : shown.display).font(Theme.bodyDigits)
                                    Text(shown.title).font(Theme.body)
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
