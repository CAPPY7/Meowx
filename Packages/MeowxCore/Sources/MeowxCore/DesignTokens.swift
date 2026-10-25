import Foundation

public struct RGB: Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

/// Shared numbers for the Mac UI. Views read these through Theme so they do not invent their own.
public enum DesignTokens {
    public static let violet = RGB(red: 106.0 / 255, green: 69.0 / 255, blue: 255.0 / 255)
    public static let indigo = RGB(red: 22.0 / 255, green: 14.0 / 255, blue: 74.0 / 255)
    public static let cyan = RGB(red: 34.0 / 255, green: 211.0 / 255, blue: 238.0 / 255)
    public static let magenta = RGB(red: 224.0 / 255, green: 64.0 / 255, blue: 251.0 / 255)
    public static let success = RGB(red: 52.0 / 255, green: 199.0 / 255, blue: 89.0 / 255)
    public static let warning = RGB(red: 255.0 / 255, green: 176.0 / 255, blue: 32.0 / 255)

    public static let spaces: [Double] = [4, 8, 12, 16, 24, 32]
    public static let radiusSmall = 10.0
    public static let radiusMedium = 16.0
    public static let radiusLarge = 24.0
    public static let title = 20.0
    public static let body = 13.0
    public static let caption = 11.0
    public static let hit = 28.0
    public static let springResponse = 0.3
    public static let springDamping = 0.85
    public static let fade = 0.18

    public static func duration(_ requested: Double, reduceMotion: Bool) -> Double {
        reduceMotion || requested < 0 ? 0 : requested
    }
}
