import AppKit
import MeowxCore
import SwiftUI

struct HomeView: View {
    var model: PlayerModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dash: CGFloat = 0

    private var cards: [ResumeStore.Card] {
        model.continueWatching().filter { card in
            guard let url = card.url else { return false }
            if url.isFileURL { return FileManager.default.fileExists(atPath: url.path) }
            return true
        }
    }

    private var recent: [URL] {
        _ = model.recentRevision
        return Array(NSDocumentController.shared.recentDocumentURLs.prefix(8))
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.indigo, Theme.videoBlack], startPoint: .top, endPoint: .bottom)
            Circle()
                .fill(Theme.accent)
                .frame(width: Theme.pictureWidth, height: Theme.pictureWidth)
                .blur(radius: Theme.s32 * 2)
                .opacity(0.35)
                .offset(x: -Theme.artwork, y: -Theme.artwork / 2)
            Circle()
                .fill(Theme.cyan)
                .frame(width: Theme.pictureWidth, height: Theme.pictureWidth)
                .blur(radius: Theme.s32 * 2)
                .opacity(0.22)
                .offset(x: Theme.artwork, y: Theme.artwork)
            ScrollView {
                VStack(spacing: Theme.s16) {
                    MeowxMark(side: Theme.artwork / 4)
                        .foregroundStyle(Theme.ink)
                        .padding(.top, Theme.s32)
                    Text("Drop a video, music or folder")
                        .font(Theme.title)
                        .foregroundStyle(Theme.ink)
                    dropZone
                    HStack(spacing: Theme.s8) {
                        Button("Open File") { model.openFiles(playNow: true) }
                            .keyboardShortcut(.defaultAction)
                        Button("Open URL") { model.urlPrompt = true }
                            .shortcutTip("openURL")
                        Button("Paste Link") { model.pasteLink() }
                            .shortcutTip("pasteLink")
                    }
                    .buttonStyle(.bordered)
                    .foregroundStyle(Theme.ink)
                    if !cards.isEmpty {
                        section("Continue watching") {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: Theme.s12) {
                                    ForEach(cards) { card in
                                        ContinueCard(card: card) {
                                            if let url = card.url { model.add(urls: [url], playNow: true) }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    if !recent.isEmpty {
                        section("Recent") {
                            VStack(spacing: Theme.s4) {
                                ForEach(recent, id: \.self) { url in
                                    Button { model.add(urls: [url], playNow: true) } label: {
                                        HStack {
                                            Image(systemName: "clock")
                                                .foregroundStyle(Theme.inkSecondary)
                                            Text(url.lastPathComponent)
                                                .font(Theme.body)
                                                .foregroundStyle(Theme.ink)
                                                .lineLimit(1)
                                            Spacer()
                                        }
                                        .padding(.horizontal, Theme.s8)
                                        .frame(minHeight: Theme.hit)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .help(url.path)
                                }
                            }
                        }
                    }
                    Button { model.shortcutPrompt = true } label: {
                        Text("Space play, F full screen, ? shortcuts")
                            .font(Theme.caption)
                            .foregroundStyle(Theme.inkSecondary)
                    }
                    .buttonStyle(.plain)
                    .shortcutTip("shortcuts")
                    .padding(.bottom, Theme.s32)
                }
                .padding(.horizontal, Theme.s24)
                .frame(maxWidth: Theme.barWidth)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: Theme.borderSweep).repeatForever(autoreverses: false)) {
                dash = Theme.s16
            }
        }
    }

    private var dropZone: some View {
        RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: model.dropTargeted ? [Theme.ink, Theme.accent] : [Theme.accent, Theme.cyan],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                style: StrokeStyle(lineWidth: model.dropTargeted ? Theme.s4 : Theme.hairline, dash: [Theme.s8, Theme.s8], dashPhase: reduceMotion ? 0 : dash)
            )
            .background {
                RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous)
                    .fill(model.dropTargeted ? Theme.accent.opacity(0.18) : Theme.inkFaint)
            }
            .frame(height: Theme.artwork / 2)
            .overlay {
                Text(model.dropTargeted ? "Drop to play" : "Drop here")
                    .font(Theme.body)
                    .foregroundStyle(Theme.ink)
            }
            .allowsHitTesting(false)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.s8) {
            Text(title)
                .font(Theme.bodyStrong)
                .foregroundStyle(Theme.ink)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ContinueCard: View {
    var card: ResumeStore.Card
    var play: () -> Void
    @State private var image: NSImage?

    var body: some View {
        Button(action: play) {
            VStack(alignment: .leading, spacing: Theme.s8) {
                ZStack {
                    Theme.inkFaint
                    if let image {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Image(systemName: "film")
                            .foregroundStyle(Theme.inkSecondary)
                    }
                }
                .frame(width: Theme.cardWidth, height: Theme.cardWidth * 9 / 16)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
                Text(card.title)
                    .font(Theme.body)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .frame(width: Theme.cardWidth, alignment: .leading)
                Text("\(TimeFormat.string(card.remaining)) left")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.inkSecondary)
                Capsule()
                    .fill(Theme.inkFaint)
                    .frame(width: Theme.cardWidth, height: Theme.progressHeight)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(Theme.accent)
                            .frame(width: Theme.cardWidth * card.fraction, height: Theme.progressHeight)
                    }
            }
        }
        .buttonStyle(.plain)
        .task(id: card.url) {
            guard let url = card.url, url.isFileURL else { return }
            ThumbnailService.shared.cachedPoster(for: url) { image = $0 }
        }
    }
}

struct AudioStage: View {
    var model: PlayerModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if let artwork = model.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: Theme.s32)
                    .overlay(Theme.indigo.opacity(0.55))
            } else {
                LinearGradient(colors: [Theme.indigo, Theme.videoBlack], startPoint: .top, endPoint: .bottom)
            }
            VStack(spacing: Theme.s16) {
                cover
                Text(model.displayTitle)
                    .font(Theme.title)
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                if !model.artist.isEmpty {
                    Text(model.artist)
                        .font(Theme.body)
                        .foregroundStyle(Theme.inkSecondary)
                }
                if !model.album.isEmpty {
                    Text(model.album)
                        .font(Theme.caption)
                        .foregroundStyle(Theme.inkTertiary)
                }
                if !model.paused {
                    EqualizerBars(moving: !reduceMotion)
                }
                lyric
            }
            .padding(Theme.s32)
        }
        .clipped()
        .allowsHitTesting(false)
    }

    @ViewBuilder private var cover: some View {
        if let artwork = model.artwork {
            Image(nsImage: artwork)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: Theme.artwork, height: Theme.artwork)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous))
                .shadow(color: Theme.videoBlack.opacity(0.45), radius: Theme.s24, y: Theme.s12)
        } else {
            RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous)
                .fill(Theme.inkFaint)
                .frame(width: Theme.artwork, height: Theme.artwork)
                .overlay {
                    Image(systemName: "music.note")
                        .font(Theme.title)
                        .foregroundStyle(Theme.inkSoft)
                }
        }
    }

    @ViewBuilder private var lyric: some View {
        if let line = LyricsFile.current(at: model.position, lines: model.lyrics) {
            Text(line)
                .font(Theme.body)
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .frame(maxWidth: Theme.copyWidth)
        } else if !model.lyricPlain.isEmpty {
            Text(model.lyricPlain)
                .font(Theme.body)
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .frame(maxWidth: Theme.copyWidth)
        }
    }
}

private struct EqualizerBars: View {
    var moving: Bool
    @State private var lifted = false

    var body: some View {
        HStack(alignment: .bottom, spacing: Theme.s4) {
            ForEach(0..<5, id: \.self) { index in
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: Theme.s4, height: height(index))
            }
        }
        .frame(height: Theme.s16, alignment: .bottom)
        .onAppear {
            guard moving else { return }
            withAnimation(.easeInOut(duration: Theme.borderSweep).repeatForever(autoreverses: true)) {
                lifted.toggle()
            }
        }
    }

    private func height(_ index: Int) -> CGFloat {
        let pattern: [CGFloat] = [Theme.s8, Theme.s16, Theme.s12, Theme.s16, Theme.s8]
        let base = pattern[index]
        guard moving else { return base }
        return lifted == (index % 2 == 0) ? base : Theme.s4
    }
}

struct ProblemCard: View {
    var model: PlayerModel

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s12) {
            Text(model.errorTitle)
                .font(Theme.bodyStrong)
                .foregroundStyle(Theme.ink)
            Text(model.errorMessage ?? "")
                .font(Theme.body)
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Theme.s8) {
                if model.errorURL?.isFileURL == true, let url = model.errorURL {
                    Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                }
                if let id = model.errorItemID, model.playlist.items.contains(where: { $0.id == id }) {
                    Button("Remove from playlist") {
                        model.remove(id: id)
                        model.dismissProblem()
                    }
                }
                Button("Dismiss") { model.dismissProblem() }
            }
            .buttonStyle(.bordered)
        }
        .padding(Theme.s16)
        .frame(maxWidth: Theme.sheetNarrow, alignment: .leading)
        .meowxGlass()
    }
}
