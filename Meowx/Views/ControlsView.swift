import SwiftUI

struct ControlsView: View {
    var model: PlayerModel
    @State private var sliderWidth: CGFloat = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            slider
            HStack(spacing: 8) {
                transport
                volume
                Spacer(minLength: 8)
                speedMenu
                subtitleMenu
                audioMenu
                loopButtons
                Button { model.screenshot() } label: { Image(systemName: "camera") }
                    .help("Screenshot")
                    .disabled(model.playlist.current == nil)
                Button { model.togglePictureInPicture() } label: { Image(systemName: model.pictureInPicture ? "pip.exit" : "pip.enter") }
                    .help("Picture in Picture")
                Button { model.toggleFullscreen() } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                    .help("Full screen")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .font(.system(size: 15))
        }
        .foregroundStyle(.primary)
    }

    private var slider: some View {
        VStack(spacing: 4) {
            if model.showThumb {
                thumbPreview
            }
            HStack(spacing: 8) {
                Text(TimeFormat.string(model.scrubbing ? model.scrub : model.position))
                    .font(.caption.monospacedDigit())
                    .frame(width: 64, alignment: .leading)
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
                .background {
                    GeometryReader { proxy in
                        Color.clear
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
                    .font(.caption.monospacedDigit())
                    .frame(width: 64, alignment: .trailing)
            }
        }
    }

    private var thumbPreview: some View {
        VStack(spacing: 4) {
            if let image = model.thumbImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 160, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            Text(TimeFormat.string(model.thumbTime ?? model.position))
                .font(.caption.monospacedDigit())
        }
        .padding(6)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
    }

    private var transport: some View {
        HStack(spacing: 2) {
            Button { model.previous() } label: { Image(systemName: "backward.fill") }
                .help("Previous")
            Button { model.togglePause() } label: {
                Image(systemName: model.paused ? "play.fill" : "pause.fill")
                    .frame(width: 22)
            }
            .help(model.paused ? "Play" : "Pause")
            Button { model.next() } label: { Image(systemName: "forward.fill") }
                .help("Next")
        }
    }

    private var volume: some View {
        HStack(spacing: 4) {
            Button { model.toggleMute() } label: {
                Image(systemName: model.muted || model.volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
            }
            .help("Mute")
            Slider(value: Binding(get: { model.muted ? 0 : model.volume }, set: { model.setVolume($0) }), in: 0...200)
                .frame(width: 90)
                .help("Volume")
        }
    }

    private var speedMenu: some View {
        Menu {
            ForEach(PlayerModel.speedSteps, id: \.self) { speed in
                Button(speedLabel(speed)) { model.setSpeed(speed) }
            }
        } label: {
            Text(speedLabel(model.speed)).font(.callout.monospacedDigit())
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Playback speed")
    }

    private var subtitleMenu: some View {
        Menu {
            Button("Off") { model.selectSubtitle(0) }
            ForEach(model.subtitleTracks) { track in
                Button(track.label) { model.selectSubtitle(track.id) }
            }
            Divider()
            Button("Add subtitle file…") { model.openSubtitleFile() }
            Button("Search online…") { model.searchOpen = true }
            Divider()
            Button("Subtitle earlier") { model.nudgeSubDelay(-0.1) }
            Button("Subtitle later") { model.nudgeSubDelay(0.1) }
        } label: {
            Image(systemName: "captions.bubble")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Subtitles")
    }

    private var audioMenu: some View {
        Menu {
            ForEach(model.audioTracks) { track in
                Button(track.label) { model.selectAudio(track.id) }
            }
            if model.audioTracks.isEmpty {
                Button("No extra audio tracks") {}.disabled(true)
            }
            Divider()
            Button("Audio earlier") { model.nudgeAudioDelay(-0.1) }
            Button("Audio later") { model.nudgeAudioDelay(0.1) }
        } label: {
            Image(systemName: "waveform")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Audio")
    }

    private var loopButtons: some View {
        HStack(spacing: 2) {
            Button("A") { model.setLoopA() }
                .font(.caption.weight(.semibold))
                .foregroundStyle(model.loopA == nil ? .primary : Color.accentColor)
                .help("Set loop start")
            Button("B") { model.setLoopB() }
                .font(.caption.weight(.semibold))
                .foregroundStyle(model.loopB == nil ? .primary : Color.accentColor)
                .help("Set loop end")
            if model.loopA != nil || model.loopB != nil {
                Button { model.clearLoop() } label: { Image(systemName: "xmark") }
                    .help("Clear A-B loop")
            }
        }
    }

    private func speedLabel(_ speed: Double) -> String {
        speed == floor(speed) ? String(format: "%.0f×", speed) : String(format: "%g×", speed)
    }
}
