import Foundation

/// An sRGB colour, written as the hex a designer reads.
///
///     RGB(0xC8402A).luminance   // WCAG relative luminance, 0...1
public struct RGB: Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(_ hex: UInt32) {
        red = Double((hex >> 16) & 0xFF) / 255
        green = Double((hex >> 8) & 0xFF) / 255
        blue = Double(hex & 0xFF) / 255
    }

    /// WCAG 2.x relative luminance.
    public var luminance: Double {
        0.2126 * Self.linear(red) + 0.7152 * Self.linear(green) + 0.0722 * Self.linear(blue)
    }

    /// WCAG contrast ratio, 1...21, in either argument order.
    public static func contrast(_ lhs: RGB, _ rhs: RGB) -> Double {
        let (high, low) = (max(lhs.luminance, rhs.luminance), min(lhs.luminance, rhs.luminance))
        return (high + 0.05) / (low + 0.05)
    }

    private static func linear(_ channel: Double) -> Double {
        channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
    }
}

/// One design token: the colour it is in light appearance and in dark.
///
///     let shu = DesignColor(light: 0xC8402A, dark: 0xD0462C)
///     Text("Focus").foregroundStyle(shu.color)
public struct DesignColor: Equatable, Sendable {
    public let light: RGB
    public let dark: RGB

    public init(light: UInt32, dark: UInt32) {
        self.light = RGB(light)
        self.dark = RGB(dark)
    }

    /// A token that does not change with appearance (priority marks).
    public init(both hex: UInt32) {
        self.init(light: hex, dark: hex)
    }
}
