import AppKit
import MeowxCore
import SwiftUI

struct SettingsView: View {
    @State private var model = PlayerModel.shared
    @State private var devices: [(id: String, name: String)] = []
    @State private var bandsOpen = true

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
            Toggle("Check for updates on launch", isOn: binding(\.checkForUpdates))
                .help("Asks GitHub if a newer release exists. Nothing is installed for you.")
            Button("Check Now") { model.checkForUpdate(manual: true) }
                .help("Check the GitHub releases page now")
            if let offer = model.updateOffer, let url = URL(string: "https://github.com/Cappy7/Meowx/releases/latest") {
                Link("Update \(offer) available", destination: url)
            }
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
            Picker("Sleep timer", selection: binding(\.sleepMinutes)) {
                Text("Off").tag(0)
                Text("15 minutes").tag(15)
                Text("30 minutes").tag(30)
                Text("45 minutes").tag(45)
                Text("60 minutes").tag(60)
                Text("90 minutes").tag(90)
            }
            .help("Pauses playback when the time is up, then turns itself off.")
            Picker("Stop after", selection: Binding(get: { model.stopAfter }, set: { model.setStopAfter($0) })) {
                Text("Keep playing").tag(StopAfter.none)
                Text("This video").tag(StopAfter.file)
                Text("This playlist").tag(StopAfter.playlist)
            }
            .help("This video stops at the next ending. This playlist finishes the remaining items without wrapping.")
            note("Arrow keys use the short step. Shift uses the long step. The side buttons and a side double-click use the medium step. Sleep and stop-after apply now.")
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
            .help("Audio output device from mpv")
            Button("Refresh devices") { refreshDevices() }
            Toggle("Normalize loudness", isOn: binding(\.loudnessNormalize))
                .help("Even out volume with dynaudnorm")
            Toggle("Night mode", isOn: binding(\.audioCompressor))
                .help("Compress loud peaks so quieter parts stay audible")
            DisclosureGroup("10-band equalizer", isExpanded: $bandsOpen) {
                Picker("Preset", selection: Binding<EqualizerPreset?>(
                    get: { EqualizerPreset.allCases.first { $0.gains == model.settings.equalizer } },
                    set: { preset in
                        guard let preset else { return }
                        model.updateSettings { $0.equalizer = preset.gains }
                    }
                )) {
                    Text("Custom").tag(Optional<EqualizerPreset>.none)
                    ForEach(EqualizerPreset.allCases, id: \.self) { preset in
                        Text(preset.rawValue.capitalized).tag(Optional(preset))
                    }
                }
                ForEach(0..<10, id: \.self) { index in
                    LabeledContent(bandTitle(index)) {
                        HStack {
                            Slider(
                                value: Binding(
                                    get: { model.settings.equalizer.indices.contains(index) ? model.settings.equalizer[index] : 0 },
                                    set: { value in
                                        model.updateSettings { settings in
                                            var bands = PlayerSettings.tenBands(settings.equalizer)
                                            bands[index] = value
                                            settings.equalizer = bands
                                        }
                                    }
                                ),
                                in: -12...12,
                                step: 0.5
                            )
                            Text(gainText(model.settings.equalizer.indices.contains(index) ? model.settings.equalizer[index] : 0))
                                .font(Theme.digits)
                                .frame(width: 64, alignment: .trailing)
                        }
                    }
                }
                Button("Reset") { model.updateSettings { $0.equalizer = EqualizerPreset.flat.gains } }
                    .help("Set every band back to 0 dB")
            }
            TextField("Preferred audio languages", text: binding(\.audioLanguage))
                .help("Comma-separated codes, for example ja,en")
            Toggle("Remember volume", isOn: binding(\.rememberVolume))
            note("The device, night mode, normalization, and equalizer apply now. A flat equalizer is not sent to mpv.")
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
            Toggle("Include file paths in diagnostics", isOn: binding(\.includePathsInLogs))
                .help("Off hides paths and file names from Copy Diagnostics and Show Logs.")
            note("Applies now.")
            Button("Show Logs") { model.logsOpen = true }
                .help("Show the recent player log")
            Button("Copy diagnostics") { model.copyDiagnostics() }
                .help("Copy version, macOS, chip, mpv, decoder, and the last 50 log lines")
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

    private func bandTitle(_ index: Int) -> String {
        ["31 Hz", "63 Hz", "125 Hz", "250 Hz", "500 Hz", "1 kHz", "2 kHz", "4 kHz", "8 kHz", "16 kHz"][index]
    }

    private func gainText(_ value: Double) -> String {
        String(format: "%+.1f dB", value)
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
                .help("Clear every shortcut override")
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
                Text("YouTube and similar sites need yt-dlp. This build looks for the copy inside Meowx, then one already on the Mac.")
                    .font(Theme.body)
                    .foregroundStyle(Theme.secondary)
            } else {
                Text("Site links open with the bundled player tools. ffmpeg is used when a site splits picture and sound.")
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

struct MediaInfoSheet: View {
    var model: PlayerModel

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s12) {
            Text("Media Info")
                .font(Theme.title)
            ScrollView {
                Text(model.currentFacts().text())
                    .font(Theme.mono)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            HStack {
                Button("Copy") { model.copyMediaInfo() }
                    .help("Copy this media info")
                Spacer()
                Button("Close") { model.infoOpen = false }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(Theme.s24)
        .frame(width: Theme.sheetMid, height: Theme.sheetMid)
    }
}

struct LogsSheet: View {
    var model: PlayerModel

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s12) {
            Text("Logs")
                .font(Theme.title)
            Text(model.settings.includePathsInLogs ? "File paths are included." : "File paths are hidden. Turn that on in Settings > Advanced.")
                .font(Theme.caption)
                .foregroundStyle(Theme.secondary)
            ScrollView {
                Text(logText)
                    .font(Theme.mono)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            HStack {
                Button("Copy") { model.copyLogs() }
                    .help("Copy the log")
                Spacer()
                Button("Close") { model.logsOpen = false }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(Theme.s24)
        .frame(width: Theme.sheetMid, height: Theme.sheetMid)
    }

    private var logText: String {
        let text = AppLog.shared.recent(limit: 200, includePaths: model.settings.includePathsInLogs)
        return text.isEmpty ? "No log lines yet." : text
    }
}
