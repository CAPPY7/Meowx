import MeowxCore
import SwiftUI

struct ControlsView: View {
    var model: PlayerModel
    @State private var sliderWidth: CGFloat = 1

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s8) {
            slider
            HStack(spacing: Theme.s8) {
                transport
                volume
                Spacer(minLength: Theme.s8)
                chaptersMenu
                pictureButton
                speedMenu
                subtitleMenu
                audioMenu
                loopButtons
                Button { model.screenshot() } label: { Image(systemName: "camera") }
                    .shortcutTip("screenshot")
                    .disabled(model.playlist.current == nil)
                Button { model.togglePictureInPicture() } label: { Image(systemName: model.pictureInPicture ? "pip.exit" : "pip.enter") }
                    .shortcutTip("pictureInPicture")
                Button { model.toggleFullscreen() } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                    .shortcutTip("fullScreen")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(MeowxIconButtonStyle())
            .foregroundStyle(Theme.primary)
        }
    }

    private var slider: some View {
        VStack(spacing: Theme.s4) {
            if model.showThumb {
                thumbPreview
            }
            HStack(spacing: Theme.s8) {
                Text(TimeFormat.string(model.scrubbing ? model.scrub : model.position))
                    .font(Theme.time)
                    .frame(width: Theme.timeWidth, alignment: .leading)
                Slider(
                    value: Binding(
                        get: { model.scrubbing ? model.scrub : model.position },
                        set: { model.scrubTo($0) }
                    ),
                    in: 0...max(model.duration, 1),
                    onEditingChanged: { editing in
                        if !editing { model.endScrub() }
                    }
                )
                .shortcutTip("seekBar")
                .overlay {
                    ChapterTicks(fractions: ChapterNav.tickFractions(
                        times: model.chapters.map(\.time),
                        duration: model.duration
                    ))
                    .allowsHitTesting(false)
                    .padding(.horizontal, Theme.s8)
                }
                .background {
                    GeometryReader { proxy in
                        Theme.videoBlack.opacity(0)
                            .onAppear { sliderWidth = proxy.size.width }
                            .onChange(of: proxy.size.width) { _, width in sliderWidth = width }
                    }
                }
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location):
                        let duration = max(model.duration, 1)
                        let ratio = min(1, max(0, location.x / max(sliderWidth, 1)))
                        model.hover(at: duration * ratio)
                    case .ended:
                        model.endHover()
                    }
                }
                Text(TimeFormat.string(model.duration))
                    .font(Theme.time)
                    .frame(width: Theme.timeWidth, alignment: .trailing)
            }
        }
    }

    private var thumbPreview: some View {
        VStack(spacing: Theme.s4) {
            if let image = model.thumbImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: Theme.thumbWidth, height: Theme.thumbHeight)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
            }
            Text(TimeFormat.string(model.thumbTime ?? model.position))
                .font(Theme.digits)
        }
        .padding(Theme.s8)
        .background(Theme.scrimStrong, in: RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
    }

    private var transport: some View {
        HStack(spacing: Theme.s4) {
            Button { model.previous() } label: { Image(systemName: "backward.fill") }
                .shortcutTip("previous")
            Button { model.togglePause() } label: {
                Image(systemName: model.paused ? "play.fill" : "pause.fill")
            }
            .shortcutTip("playPause", title: model.paused ? "Play" : "Pause")
            Button { model.next() } label: { Image(systemName: "forward.fill") }
                .shortcutTip("next")
        }
    }

    private var volume: some View {
        HStack(spacing: Theme.s4) {
            Button { model.toggleMute() } label: {
                Image(systemName: model.muted || model.volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
            }
            .shortcutTip("mute")
            Slider(value: Binding(get: { model.muted ? 0 : model.volume }, set: { model.setVolume($0) }), in: 0...200)
                .frame(width: Theme.volumeWidth)
                .shortcutTip("volumeSlider", title: "Volume (Up/Down, Shift ±10)")
        }
    }

    private var chaptersMenu: some View {
        Menu {
            Button("Previous Chapter") { model.stepChapter(-1) }
            Button("Next Chapter") { model.stepChapter(1) }
            Divider()
            if model.chapters.isEmpty {
                Text("No chapters")
            } else {
                ForEach(model.chapters) { chapter in
                    Button(chapterTitle(chapter)) { model.seekChapter(chapter.index) }
                }
            }
        } label: {
            Image(systemName: "list.number")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .shortcutTip("chapters")
    }

    private var pictureButton: some View {
        Button { model.togglePicturePanel() } label: {
            Image(systemName: "sun.max")
        }
        .foregroundStyle(model.picture.isNeutral ? Theme.primary : Theme.accent)
        .shortcutTip("picture")
    }

    private func chapterTitle(_ chapter: MediaChapter) -> String {
        let name = ChapterNav.displayTitle(index: chapter.index, title: chapter.title)
        let mark = chapter.index == model.chapterIndex ? "✓ " : ""
        return "\(mark)\(name)  \(TimeFormat.string(chapter.time))"
    }

    private var speedMenu: some View {
        Menu {
            ForEach(PlayerModel.speedSteps, id: \.self) { speed in
                Button(speedLabel(speed)) { model.setSpeed(speed) }
            }
        } label: {
            Text(speedLabel(model.speed)).font(Theme.bodyDigits)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .shortcutTip("speedUp", title: "Speed ([ ] \\)")
    }

    private var subtitleMenu: some View {
        Menu {
            Picker("Subtitles", selection: Binding(get: { model.subtitleTrackID }, set: { model.selectSubtitle($0) })) {
                Text("Off").tag(0)
                ForEach(model.subtitleTracks) { track in
                    Text(track.label).tag(track.id)
                }
            }
            .pickerStyle(.inline)
            if model.subtitleTracks.isEmpty {
                Text("None available")
            }
            Divider()
            Button("Add subtitle file…") { model.openSubtitleFile() }
            Button("Search online…") { model.searchOpen = true }
            Divider()
            Text(String(format: "Subtitle delay: %+.1f s", model.subDelay))
            Button("Subtitle earlier") { model.nudgeSubDelay(-0.1) }
            Button("Subtitle later") { model.nudgeSubDelay(0.1) }
        } label: {
            Image(systemName: "captions.bubble")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .shortcutTip("cycleSubtitles")
    }

    private var audioMenu: some View {
        Menu {
            if model.audioTracks.isEmpty {
                Text("None available")
            } else {
                Picker("Audio", selection: Binding(get: { model.audioTrackID }, set: { model.selectAudio($0) })) {
                    ForEach(model.audioTracks) { track in
                        Text(track.label).tag(track.id)
                    }
                }
                .pickerStyle(.inline)
            }
            Divider()
            Text(String(format: "Audio delay: %+.1f s", model.audioDelay))
            Button("Audio earlier") { model.nudgeAudioDelay(-0.1) }
            Button("Audio later") { model.nudgeAudioDelay(0.1) }
        } label: {
            Image(systemName: "waveform")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .shortcutTip("cycleAudio")
    }

    private var loopButtons: some View {
        HStack(spacing: Theme.s4) {
            Button("A") { model.setLoopA() }
                .font(Theme.captionStrong)
                .foregroundStyle(model.loopA == nil ? Theme.primary : Theme.accent)
                .shortcutTip("loopCycle", title: "Set loop start")
            Button("B") { model.setLoopB() }
                .font(Theme.captionStrong)
                .foregroundStyle(model.loopB == nil ? Theme.primary : Theme.accent)
                .shortcutTip("loopCycle", title: "Set loop end")
            if model.loopA != nil || model.loopB != nil {
                Button { model.clearLoop() } label: { Image(systemName: "xmark") }
                    .help("Clear A-B loop")
                    .accessibilityLabel("Clear A-B loop")
            }
        }
    }

    private func speedLabel(_ speed: Double) -> String {
        speed == floor(speed) ? String(format: "%.0f×", speed) : String(format: "%g×", speed)
    }
}

extension View {
    func shortcutTip(_ id: String, title: String? = nil) -> some View {
        let text = ShortcutCatalog.help(id, title: title)
        return help(text).accessibilityLabel(text)
    }
}

private struct ChapterTicks: View {
    var fractions: [Double]

    var body: some View {
        GeometryReader { proxy in
            ForEach(Array(fractions.enumerated()), id: \.offset) { _, fraction in
                Rectangle()
                    .fill(Theme.tick)
                    .frame(width: Theme.hairline, height: min(Theme.s8, max(Theme.s4, proxy.size.height * 0.45)))
                    .position(x: proxy.size.width * fraction, y: proxy.size.height / 2)
            }
        }
    }
}

struct PicturePanel: View {
    var model: PlayerModel

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s8) {
            HStack {
                Text("Picture")
                    .font(Theme.bodyStrong)
                Spacer()
                Button("Reset") { model.resetPicture() }
                    .help("Reset brightness, contrast, saturation, gamma, and hue")
                    .meowxHit()
                Button { model.closePicturePanel() } label: { Image(systemName: "xmark") }
                    .buttonStyle(MeowxIconButtonStyle())
                    .help("Close picture adjustments")
                    .accessibilityLabel("Close picture adjustments")
            }
            row("Brightness", model.picture.brightness) { value in model.updatePicture { $0.brightness = value } }
            row("Contrast", model.picture.contrast) { value in model.updatePicture { $0.contrast = value } }
            row("Saturation", model.picture.saturation) { value in model.updatePicture { $0.saturation = value } }
            row("Gamma", model.picture.gamma) { value in model.updatePicture { $0.gamma = value } }
            row("Hue", model.picture.hue) { value in model.updatePicture { $0.hue = value } }
        }
        .padding(Theme.s12)
        .frame(width: Theme.pictureWidth)
        .meowxSurface(Theme.radiusMedium)
    }

    private func row(_ title: String, _ value: Double, set: @escaping (Double) -> Void) -> some View {
        HStack(spacing: Theme.s8) {
            Text(title)
                .font(Theme.caption)
                .frame(width: Theme.pictureLabel, alignment: .leading)
            Slider(value: Binding(get: { value }, set: set), in: -100...100)
            Text("\(Int(value.rounded()))")
                .font(Theme.digits)
                .frame(width: Theme.pictureValue, alignment: .trailing)
        }
    }
}
