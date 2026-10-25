import AppKit
import MeowxCore
import SwiftUI

enum Theme {
    static let accent = color(DesignTokens.violet)
    static let indigo = color(DesignTokens.indigo)
    static let cyan = color(DesignTokens.cyan)
    static let magenta = color(DesignTokens.magenta)
    static let success = color(DesignTokens.success)
    static let warning = color(DesignTokens.warning)
    static let primary = Color.primary
    static let secondary = Color.secondary
    static let videoBlack = Color.black
    static let clear = Color.clear
    static let ink = Color.white
    static let inkSoft = Color.white.opacity(0.85)
    static let inkSecondary = Color.white.opacity(0.72)
    static let inkTertiary = Color.white.opacity(0.6)
    static let inkFaint = Color.white.opacity(0.08)
    static let inkTrack = Color.white.opacity(0.28)
    static let tick = Color.white.opacity(0.9)
    static let scrim = Color.black.opacity(0.55)
    static let scrimStrong = Color.black.opacity(0.72)
    static let scrimSolid = Color.black.opacity(0.92)
    static let dropScrim = Color.black.opacity(0.35)
    static let dropBorder = Color.white.opacity(0.85)
    static let nsVideoBlack = NSColor.black

    static let s4 = CGFloat(DesignTokens.spaces[0])
    static let s8 = CGFloat(DesignTokens.spaces[1])
    static let s12 = CGFloat(DesignTokens.spaces[2])
    static let s16 = CGFloat(DesignTokens.spaces[3])
    static let s24 = CGFloat(DesignTokens.spaces[4])
    static let s32 = CGFloat(DesignTokens.spaces[5])
    static let radiusSmall = CGFloat(DesignTokens.radiusSmall)
    static let radiusMedium = CGFloat(DesignTokens.radiusMedium)
    static let radiusLarge = CGFloat(DesignTokens.radiusLarge)
    static let hit = CGFloat(DesignTokens.hit)

    static let title = Font.system(size: DesignTokens.title, weight: .semibold)
    static let body = Font.system(size: DesignTokens.body)
    static let bodyStrong = Font.system(size: DesignTokens.body, weight: .semibold)
    static let bodyDigits = Font.system(size: DesignTokens.body).monospacedDigit()
    static let caption = Font.system(size: DesignTokens.caption)
    static let captionStrong = Font.system(size: DesignTokens.caption, weight: .semibold)
    static let digits = Font.system(size: DesignTokens.caption).monospacedDigit()
    static let time = Font.system(size: DesignTokens.title, weight: .medium, design: .rounded).monospacedDigit()
    static let mono = Font.system(size: DesignTokens.caption, design: .monospaced)
    static let symbol = Font.system(size: DesignTokens.body, weight: .medium)

    static let mark: CGFloat = 64
    static let artwork: CGFloat = 320
    static let placeholderArt: CGFloat = 220
    static let timeWidth: CGFloat = 64
    static let volumeWidth: CGFloat = 90
    static let thumbWidth: CGFloat = 160
    static let thumbHeight: CGFloat = 90
    static let pictureWidth: CGFloat = 280
    static let pictureLabel: CGFloat = 72
    static let pictureValue: CGFloat = 32
    static let hairline: CGFloat = 2
    static let progressWidth: CGFloat = 120
    static let progressHeight: CGFloat = 4
    static let copyWidth: CGFloat = 420
    static let sheetNarrow: CGFloat = 360
    static let sheetMid: CGFloat = 460
    static let sheetSearchWidth: CGFloat = 480
    static let sheetSearchHeight: CGFloat = 420
    static let listMin: CGFloat = 180
    static let settingsWidth: CGFloat = 620
    static let settingsHeight: CGFloat = 560
    static let statsLabel: CGFloat = 64
    static let windowMinWidth: CGFloat = 780
    static let windowMinHeight: CGFloat = 480
    static let playlistWidth: CGFloat = 320
    static let pictureInset: CGFloat = 56
    static let barWidth: CGFloat = 760
    static let playSize: CGFloat = 44
    static let seekRest: CGFloat = 6
    static let seekHover: CGFloat = 10
    static let borderSweep: Double = 1.2
    static let cardWidth: CGFloat = 168

    static func fade(_ reduceMotion: Bool) -> Animation? {
        let duration = DesignTokens.duration(DesignTokens.fade, reduceMotion: reduceMotion)
        return duration == 0 ? nil : .easeInOut(duration: duration)
    }

    static func spring(_ reduceMotion: Bool) -> Animation? {
        guard DesignTokens.duration(DesignTokens.springResponse, reduceMotion: reduceMotion) > 0 else { return nil }
        return .spring(response: DesignTokens.springResponse, dampingFraction: DesignTokens.springDamping)
    }

    static func appKitFade(reduceMotion: Bool) -> TimeInterval {
        DesignTokens.duration(DesignTokens.fade, reduceMotion: reduceMotion)
    }

    private static func color(_ rgb: RGB) -> Color {
        Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }
}

struct MeowxMark: View {
    var side: CGFloat = Theme.mark

    var body: some View {
        Image("MeowxMark")
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .frame(width: side, height: side)
            .accessibilityHidden(true)
    }
}

struct MeowxIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        IconFace(configuration: configuration)
    }
}

private struct IconFace: View {
    let configuration: ButtonStyleConfiguration
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        configuration.label
            .font(Theme.symbol)
            .symbolRenderingMode(.hierarchical)
            .frame(minWidth: Theme.hit, minHeight: Theme.hit)
            .background(configuration.isPressed || hovering ? Theme.inkFaint : Theme.clear, in: Circle())
            .opacity(configuration.isPressed ? 0.65 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1)
            .contentShape(Circle())
            .onHover { hovering = $0 }
            .animation(Theme.fade(reduceMotion), value: hovering)
            .animation(Theme.fade(reduceMotion), value: configuration.isPressed)
    }
}

struct MeowxPlainStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.65 : 1)
    }
}

private struct MeowxFocusRing: ViewModifier {
    @FocusState private var focused: Bool
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .focused($focused)
            .overlay {
                Circle()
                    .strokeBorder(Theme.accent, lineWidth: CGFloat(AccessibilityPaint.ringWidth(increaseContrast: contrast == .increased)))
                    .opacity(focused ? 1 : 0)
                    .allowsHitTesting(false)
            }
            .animation(Theme.fade(reduceMotion), value: focused)
    }
}

extension View {
    func meowxFocusRing() -> some View { modifier(MeowxFocusRing()) }
}

private struct MeowxSurface: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    var radius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let solid = AccessibilityPaint.usesSolidSurface(reduceTransparency: reduceTransparency, increaseContrast: contrast == .increased)
        if solid {
            content
                .background(Theme.scrimSolid, in: shape)
                .overlay(shape.strokeBorder(Theme.dropBorder, lineWidth: CGFloat(AccessibilityPaint.ringWidth(increaseContrast: contrast == .increased))))
        } else {
            content.background(.ultraThinMaterial, in: shape)
        }
    }
}

private struct MeowxPill: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let solid = AccessibilityPaint.usesSolidSurface(reduceTransparency: reduceTransparency, increaseContrast: contrast == .increased)
        if solid {
            content
                .background(Theme.scrimSolid, in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.dropBorder, lineWidth: CGFloat(AccessibilityPaint.ringWidth(increaseContrast: contrast == .increased))))
        } else {
            content.background(.ultraThinMaterial, in: Capsule())
        }
    }
}

extension View {
    func meowxSurface(_ radius: CGFloat) -> some View {
        modifier(MeowxSurface(radius: radius))
    }

    func meowxPill() -> some View {
        modifier(MeowxPill())
    }

    func meowxGlass(capsule: Bool = false) -> some View {
        modifier(MeowxGlass(capsule: capsule))
    }

    func meowxHit() -> some View {
        frame(minWidth: Theme.hit, minHeight: Theme.hit)
    }
}

private struct MeowxGlass: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    var capsule: Bool

    func body(content: Content) -> some View {
        let rect = RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous)
        let solid = AccessibilityPaint.usesSolidSurface(reduceTransparency: reduceTransparency, increaseContrast: contrast == .increased)
        let width = CGFloat(AccessibilityPaint.ringWidth(increaseContrast: contrast == .increased))
        if solid {
            if capsule {
                content
                    .background(Theme.scrimSolid, in: Capsule())
                    .overlay(Capsule().strokeBorder(Theme.dropBorder, lineWidth: width))
            } else {
                content
                    .background(Theme.scrimSolid, in: rect)
                    .overlay(rect.strokeBorder(Theme.dropBorder, lineWidth: width))
            }
        } else if capsule {
            content.glassEffect(.regular, in: Capsule())
        } else {
            content.glassEffect(.regular, in: rect)
        }
    }
}
