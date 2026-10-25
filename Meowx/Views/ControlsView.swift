import MeowxCore
import SwiftUI

struct ControlsView: View {
    var model: PlayerModel
    @State private var tracksOpen = false
    @State private var speedOpen = false
    @State private var seekHover = false
    @State private var seekWidth: CGFloat = 1

    var body: some View {
        VStack(spacing: Theme.s8) {
            seekRow
            buttonRow
        }
        .padding(.horizontal, Theme.s16)
        .padding(.vertical, Theme.s12)
        .frame(maxWidth: Theme.barWidth)
        .meowxGlass()
        .onChange(of: tracksOpen) { _, _ in notePanels() }
        .onChange(of: speedOpen) { _, _ in notePanels() }
    }

    private var seekRow: some View {
        HStack(spacing: Theme.s8) {
            BufferingMark(model: model)
            ElapsedClock(model: model)
            SeekBar(model: model, hovering: $seekHover, width: $seekWidth)
            RemainingClock(model: model)
        }
        .foregroundStyle(Theme.ink)
        .overlay(alignment: .top) {
            HoverCard(model: model, width: seekWidth)
        }
    }

    private var buttonRow: some View {
        ZStack {
            HStack(spacing: Theme.s8) {
                volume
                Spacer(minLength: Theme.s4)
                tracksButton
                Button(action: model.togglePlaylist) {
                    Image(systemName: model.playlistShown ? "list.bullet.rectangle.fill" : "list.bullet.rectangle")
                }
                .buttonStyle(MeowxIconButtonStyle()).meowxFocusRing()
                .shortcutTip("showPlaylist")
                Button { model.openFiles(playNow: true) } label: { Image(systemName: "folder") }
                    .buttonStyle(MeowxIconButtonStyle()).meowxFocusRing()
                    .shortcutTip("open")
                Button { model.urlPrompt = true } label: { Image(systemName: "link") }
                    .buttonStyle(MeowxIconButtonStyle()).meowxFocusRing()
                    .shortcutTip("openURL")
                speedButton
                moreMenu
                Button { model.toggleFullscreen() } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                    .buttonStyle(MeowxIconButtonStyle()).meowxFocusRing()
                    .shortcutTip("fullScreen")
            }
            HStack(spacing: Theme.s12) {
                jumpButton(-model.settings.seekMedium, symbol: "gobackward.10", help: "Back \(Int(model.settings.seekMedium)) seconds")
                playButton
                jumpButton(model.settings.seekMedium, symbol: "goforward.10", help: "Forward \(Int(model.settings.seekMedium)) seconds")
            }
        }
        .foregroundStyle(Theme.ink)
    }

    private var playButton: some View {
        Button { model.togglePause() } label: {
            Image(systemName: model.paused ? "play.fill" : "pause.fill")
                .font(Theme.title)
                .foregroundStyle(Theme.ink)
                .frame(width: Theme.playSize, height: Theme.playSize)
                .background(Theme.accent, in: Circle())
        }
        .buttonStyle(MeowxPlainStyle())
        .meowxFocusRing()
        .shortcutTip("playPause", title: model.paused ? "Play" : "Pause")
    }

    private func jumpButton(_ delta: Double, symbol: String, help: String) -> some View {
        Button { model.seek(by: delta) } label: { Image(systemName: symbol) }
            .buttonStyle(MeowxIconButtonStyle()).meowxFocusRing()
            .help(help)
            .accessibilityLabel(help)
            .disabled(model.playlist.current == nil)
    }

    private var volume: some View {
        HStack(spacing: Theme.s8) {
            Button { model.toggleMute() } label: {
                Image(systemName: model.muted || model.volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
            }
            .buttonStyle(MeowxIconButtonStyle()).meowxFocusRing()
            .shortcutTip("mute")
            VolumeSlider(model: model)
                .frame(width: Theme.volumeWidth)
                .shortcutTip("volumeSlider", title: "Volume (Up/Down, Shift ±10)")
        }
    }

    private var tracksButton: some View {
        Button { tracksOpen = true } label: { Image(systemName: "captions.bubble") }
            .buttonStyle(MeowxIconButtonStyle()).meowxFocusRing()
            .help("Audio and subtitles")
            .accessibilityLabel("Audio and subtitles")
            .popover(isPresented: $tracksOpen, arrowEdge: .top) {
                TracksPopover(model: model)
            }
    }

    private var speedButton: some View {
        Button { speedOpen = true } label: {
            Text(speedLabel(model.speed)).font(Theme.bodyDigits)
        }
        .buttonStyle(MeowxPlainStyle())
        .padding(.horizontal, Theme.s8)
        .frame(minWidth: Theme.hit, minHeight: Theme.hit)
        .meowxPill()
        .meowxFocusRing()
        .shortcutTip("speedUp", title: "Speed ([ ] \\)")
        .popover(isPresented: $speedOpen, arrowEdge: .top) {
            SpeedPopover(model: model)
        }
    }

    private var moreMenu: some View {
        Menu {
            Button("Previous") { model.previous() }
            Button("Next") { model.next() }
            Divider()
            Button("Set Loop A") { model.setLoopA() }
                .shortcutTip("loopCycle", title: "Set loop start")
            Button("Set Loop B") { model.setLoopB() }
                .shortcutTip("loopCycle", title: "Set loop end")
            Button("Clear A-B Loop") { model.clearLoop() }
                .disabled(model.loopA == nil && model.loopB == nil)
            Button(model.fileLoop ? "Loop File Is On" : "Loop File") { model.toggleFileLoop() }
                .shortcutTip("loopFile")
            Divider()
            Button("Screenshot") { model.screenshot() }
                .shortcutTip("screenshot")
                .disabled(model.playlist.current == nil)
            Button(model.pictureInPicture ? "Leave Floating Window" : "Floating Window") { model.togglePictureInPicture() }
                .shortcutTip("pictureInPicture")
            Button("Picture Adjustments") { model.togglePicturePanel() }
                .shortcutTip("picture")
            Button(model.statsVisible ? "Hide Stats" : "Stats") { model.toggleStats() }
                .shortcutTip("stats")
            Button("Go to Time…") { model.timePrompt = true }
                .shortcutTip("jump")
            Button("Media Info") { model.showMediaInfo() }
                .help("Container, tracks, bitrate, and path (Cmd+I)")
            Button("Add Subtitle…") { model.openSubtitleFile() }
                .disabled(model.playlist.current == nil)
            Button("Show in Finder") { model.revealCurrent() }
                .disabled(model.playlist.current?.url.isFileURL != true)
            Button("Keyboard Shortcuts") { model.shortcutPrompt = true }
            Divider()
            Menu("Chapters") {
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
            }
            Menu("Video") {
                Button("Rotate 90°") { model.rotateClockwise() }
                Button("Cycle Aspect") { model.cycleAspect() }
                Button("Flip Horizontal") { model.toggleFlipHorizontal() }
                Button("Flip Vertical") { model.toggleFlipVertical() }
                Button("Cycle Crop") { model.cycleCrop() }
                Button("Deinterlace") { model.toggleDeinterlace() }
                Button("Reset Zoom and Pan") { model.resetZoomAndPan() }
                Button("Zoom In") { model.nudgeZoom(0.1) }
                    .help("Zoom in (Cmd+=)")
                Button("Zoom Out") { model.nudgeZoom(-0.1) }
                    .help("Zoom out (Cmd+-)")
                Button("Smaller Subtitles") { model.nudgeSubtitleSize(-4) }
                    .help("Smaller subtitles (-)")
                Button("Larger Subtitles") { model.nudgeSubtitleSize(4) }
                    .help("Larger subtitles (=)")
            }
            Divider()
            Button(model.stopAfter == .none ? "Stop After Off" : (model.stopAfter == .file ? "Stop After This Video" : "Stop After Playlist")) {
                let next: StopAfter = model.stopAfter == .none ? .file : (model.stopAfter == .file ? .playlist : .none)
                model.setStopAfter(next)
            }
            .help("Cycle: keep playing, stop after this video, stop after this playlist")
            Menu("Sleep Timer") {
                Button("Off") { model.updateSettings { $0.sleepMinutes = 0 } }
                Button("15 minutes") { model.updateSettings { $0.sleepMinutes = 15 } }
                Button("30 minutes") { model.updateSettings { $0.sleepMinutes = 30 } }
                Button("45 minutes") { model.updateSettings { $0.sleepMinutes = 45 } }
                Button("60 minutes") { model.updateSettings { $0.sleepMinutes = 60 } }
                Button("90 minutes") { model.updateSettings { $0.sleepMinutes = 90 } }
            }
            .help("Pause playback after a while. It turns off when it fires.")
        } label: {
            Image(systemName: "ellipsis")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .frame(minWidth: Theme.hit, minHeight: Theme.hit)
        .help("More")
        .accessibilityLabel("More")
    }

    private func chapterTitle(_ chapter: MediaChapter) -> String {
        let name = ChapterNav.displayTitle(index: chapter.index, title: chapter.title)
        let mark = chapter.index == model.chapterIndex ? "✓ " : ""
        return "\(mark)\(name)  \(TimeFormat.string(chapter.time))"
    }

    private func speedLabel(_ speed: Double) -> String {
        speed == floor(speed) ? String(format: "%.0f×", speed) : String(format: "%g×", speed)
    }

    private func notePanels() {
        model.transportOpen = tracksOpen || speedOpen
        if model.transportOpen { model.poke() }
    }
}

private struct BufferingMark: View {
    var model: PlayerModel

    var body: some View {
        if model.opening || model.buffering {
            ProgressView()
                .controlSize(.small)
                .accessibilityLabel("Buffering")
        }
    }
}

private struct ElapsedClock: View {
    var model: PlayerModel

    var body: some View {
        let shown = model.scrubbing ? model.scrub : model.position
        Text(TimeFormat.string(shown))
            .font(Theme.digits)
            .frame(width: Theme.timeWidth, alignment: .leading)
            .accessibilityLabel("Elapsed")
            .accessibilityValue(TimeFormat.string(shown))
    }
}

private struct RemainingClock: View {
    var model: PlayerModel

    var body: some View {
        Button(action: model.toggleTimeReadout) {
            Text(text)
                .font(Theme.digits)
                .frame(width: Theme.timeWidth, alignment: .trailing)
        }
        .buttonStyle(MeowxPlainStyle())
        .meowxFocusRing()
        .help(model.settings.showRemainingTime ? "Show total length" : "Show time remaining")
        .accessibilityLabel(model.settings.showRemainingTime ? "Time remaining" : "Total length")
        .accessibilityValue(text)
    }

    private var text: String {
        let seconds = TimeReadout.seconds(
            position: model.scrubbing ? model.scrub : model.position,
            duration: model.duration,
            remaining: model.settings.showRemainingTime
        )
        let shown = TimeFormat.string(seconds)
        return model.settings.showRemainingTime ? "−\(shown)" : shown
    }
}

private struct HoverCard: View {
    var model: PlayerModel
    var width: CGFloat

    var body: some View {
        if model.showThumb {
            card
                .offset(y: -(Theme.thumbHeight + Theme.s16))
                .offset(x: shift)
                .allowsHitTesting(false)
        }
    }

    private var card: some View {
        let time = model.thumbTime ?? model.position
        let index = ChapterNav.index(at: time, chapters: model.chapters)
        let chapter = model.chapters.first { $0.index == index }
        return VStack(spacing: Theme.s4) {
            if let image = model.thumbImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: Theme.thumbWidth, height: Theme.thumbHeight)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
            }
            Text(TimeFormat.string(time)).font(Theme.digits)
            if let chapter {
                Text(ChapterNav.displayTitle(index: chapter.index, title: chapter.title))
                    .font(Theme.caption)
                    .lineLimit(1)
            }
        }
        .padding(Theme.s8)
        .meowxGlass()
        .accessibilityElement(children: .combine)
    }

    private var shift: CGFloat {
        let duration = max(model.duration, 1)
        let fraction = min(1, max(0, (model.thumbTime ?? model.position) / duration))
        return (fraction - 0.5) * width
    }
}

private struct SeekBar: View {
    var model: PlayerModel
    @Binding var hovering: Bool
    @Binding var width: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shimmer: CGFloat = -0.4

    var body: some View {
        GeometryReader { proxy in
            let span = BufferSpan.fractions(
                position: model.scrubbing ? model.scrub : model.position,
                cachedAhead: model.cacheSeconds,
                duration: model.duration
            )
            let track = hovering ? Theme.seekHover : Theme.seekRest
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.inkFaint)
                Capsule()
                    .fill(Theme.inkTrack)
                    .frame(width: proxy.size.width * max(0, span.bufferEnd - span.bufferStart))
                    .offset(x: proxy.size.width * span.bufferStart)
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: proxy.size.width * span.played)
                if model.buffering {
                    Capsule()
                        .fill(Theme.inkSoft)
                        .frame(width: proxy.size.width * 0.28)
                        .offset(x: proxy.size.width * shimmer)
                        .opacity(reduceMotion ? 0.45 : 1)
                        .allowsHitTesting(false)
                }
                ChapterTicks(fractions: ChapterNav.tickFractions(
                    times: model.chapters.map(\.time),
                    duration: model.duration
                ))
                Circle()
                    .fill(Theme.ink)
                    .frame(width: hovering ? Theme.s12 : Theme.s8, height: hovering ? Theme.s12 : Theme.s8)
                    .offset(x: proxy.size.width * span.played - (hovering ? Theme.s12 : Theme.s8) / 2)
            }
            .frame(height: track)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                width = proxy.size.width
                let ratio = min(1, max(0, value.location.x / max(proxy.size.width, 1)))
                model.scrubTo(max(model.duration, 0) * ratio)
            }.onEnded { _ in
                model.endScrub()
            })
            .onContinuousHover { phase in
                width = proxy.size.width
                switch phase {
                case .active(let location):
                    hovering = true
                    let ratio = min(1, max(0, location.x / max(proxy.size.width, 1)))
                    model.hover(at: max(model.duration, 0) * ratio)
                case .ended:
                    hovering = false
                    model.endHover()
                }
            }
            .onAppear {
                width = proxy.size.width
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                    shimmer = 1
                }
            }
            .animation(Theme.fade(reduceMotion), value: hovering)
        }
        .frame(height: Theme.s16)
        .shortcutTip("seekBar")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Playback position")
        .accessibilityValue(spoken)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: model.seek(by: model.settings.seekShort)
            case .decrement: model.seek(by: -model.settings.seekShort)
            default: break
            }
        }
    }

    private var spoken: String {
        let time = model.scrubbing ? model.scrub : model.position
        let index = ChapterNav.index(at: time, chapters: model.chapters)
        let chapter = model.chapters.first { $0.index == index }
        let title = chapter.map { ChapterNav.displayTitle(index: $0.index, title: $0.title) }
        return SeekAccess.value(position: time, duration: model.duration, chapterTitle: title)
    }
}

private struct VolumeSlider: View {
    var model: PlayerModel

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let fraction = VolumeTrack.fraction(volume: model.volume, muted: model.muted)
            let knob = Theme.s12
            let center = CGFloat(VolumeTrack.knobCenter(fraction: fraction, width: Double(width), knob: Double(knob)))
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.inkTrack)
                Capsule()
                    .fill(fraction > 0.5 ? Theme.warning : Theme.accent)
                    .frame(width: max(knob / 2, CGFloat(fraction) * width))
                Circle()
                    .fill(Theme.ink)
                    .frame(width: knob, height: knob)
                    .offset(x: center - knob / 2)
            }
            .frame(height: Theme.seekRest)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                let ratio = min(1, max(0, value.location.x / max(width, 1)))
                model.setVolume(ratio * 200)
            })
        }
        .frame(height: Theme.s16)
        .accessibilityLabel("Volume")
        .accessibilityValue("\(Int((model.muted ? 0 : model.volume).rounded())) percent")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: model.nudgeVolume(5)
            case .decrement: model.nudgeVolume(-5)
            default: break
            }
        }
    }
}

private struct TracksPopover: View {
    var model: PlayerModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s12) {
            Text("Audio").font(Theme.bodyStrong)
            if model.audioTracks.isEmpty {
                Text("None available").font(Theme.caption).foregroundStyle(Theme.secondary)
            } else {
                ForEach(model.audioTracks) { track in
                    trackRow(track, on: model.audioTrackID == track.id) { model.selectAudio(track.id) }
                }
            }
            Stepper(String(format: "Audio delay %+.1f s", model.audioDelay), onIncrement: { model.nudgeAudioDelay(0.1) }, onDecrement: { model.nudgeAudioDelay(-0.1) })
                .font(Theme.caption)
            Divider()
            Text("Subtitles").font(Theme.bodyStrong)
            trackChoice("Off", detail: "", on: model.subtitleTrackID <= 0) { model.selectSubtitle(0) }
            ForEach(model.subtitleTracks) { track in
                trackRow(track, on: model.subtitleTrackID == track.id) { model.selectSubtitle(track.id) }
            }
            Stepper(String(format: "Subtitle delay %+.1f s", model.subDelay), onIncrement: { model.nudgeSubDelay(0.1) }, onDecrement: { model.nudgeSubDelay(-0.1) })
                .font(Theme.caption)
            HStack {
                Button("Add subtitle file…") { model.openSubtitleFile() }
                Button("Search online…") { model.searchOpen = true }
            }
        }
        .padding(Theme.s16)
        .frame(width: Theme.playlistWidth)
        .focusSection()
        .onExitCommand { dismiss() }
    }

    private func trackRow(_ track: MediaTrack, on: Bool, action: @escaping () -> Void) -> some View {
        trackChoice(track.language.isEmpty ? track.title : track.language, detail: detail(track), on: on, action: action)
    }

    private func trackChoice(_ title: String, detail: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Theme.s8) {
                Image(systemName: on ? "checkmark" : "circle")
                    .foregroundStyle(on ? Theme.accent : Theme.secondary)
                    .frame(width: Theme.s16)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title.isEmpty ? "Track" : title).font(Theme.body)
                    if !detail.isEmpty {
                        Text(detail).font(Theme.caption).foregroundStyle(Theme.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(MeowxPlainStyle())
        .meowxFocusRing()
        .accessibilityLabel(on ? "\(title), selected" : title)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func detail(_ track: MediaTrack) -> String {
        [track.codec, track.channels].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

private struct SpeedPopover: View {
    var model: PlayerModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s12) {
            Text("Speed").font(Theme.bodyStrong)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: Theme.hit * 2), spacing: Theme.s8)], spacing: Theme.s8) {
                ForEach(SpeedPresets.values, id: \.self) { speed in
                    Button(label(speed)) { model.setSpeed(speed) }
                        .buttonStyle(MeowxPlainStyle())
                        .meowxFocusRing()
                        .frame(maxWidth: .infinity, minHeight: Theme.hit)
                        .foregroundStyle(abs(model.speed - speed) < 0.02 ? Theme.ink : Theme.primary)
                        .background(abs(model.speed - speed) < 0.02 ? Theme.accent : Theme.inkFaint, in: Capsule())
                        .accessibilityLabel("Speed \(label(speed))")
                        .accessibilityAddTraits(abs(model.speed - speed) < 0.02 ? .isSelected : [])
                }
            }
            Slider(value: Binding(get: { model.speed }, set: { model.setSpeed($0) }), in: 0.25...4)
                .accessibilityLabel("Speed")
                .accessibilityValue(label(model.speed))
            Text(label(model.speed)).font(Theme.digits).foregroundStyle(Theme.secondary)
        }
        .padding(Theme.s16)
        .frame(width: Theme.pictureWidth)
        .focusSection()
        .onExitCommand { dismiss() }
    }

    private func label(_ speed: Double) -> String {
        abs(speed - speed.rounded()) < 0.001 ? String(format: "%.0fx", speed) : String(format: "%gx", speed)
    }
}

extension View {
    func shortcutTip(_ id: String, title: String? = nil) -> some View {
        let command = ShortcutCatalog.command(id).map {
            ShortcutMap.resolved($0, overrides: PlayerModel.shared.settings.shortcutOverrides)
        }
        let text = command?.help(title: title) ?? (title ?? id)
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
        .allowsHitTesting(false)
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
                    .buttonStyle(MeowxIconButtonStyle()).meowxFocusRing()
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
                .accessibilityLabel(title)
                .accessibilityValue("\(Int(value.rounded()))")
            Text("\(Int(value.rounded()))")
                .font(Theme.digits)
                .frame(width: Theme.pictureValue, alignment: .trailing)
        }
    }
}
