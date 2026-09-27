import Foundation

@testable import OmakaseFeatures

/// A colour in the CIE 1976 (L*, a*, b*) space.
private struct LabColor {
    let lightness: Double
    let redGreenAxis: Double
    let yellowBlueAxis: Double
}

/// A colour in CIE XYZ, D65.
private struct XYZColor {
    let xComponent: Double
    let yComponent: Double
    let zComponent: Double
}

/// CIE Lab conversion and ΔE76, so `KindTintTests` can pin how different two
/// signal colours must look (spec §2, "Tests"). Test-only: it must not ship.
enum ColorDistance {
    /// ΔE76: the Euclidean distance between two colours' CIE Lab coordinates.
    static func deltaE76(_ lhs: RGB, _ rhs: RGB) -> Double {
        let (leftLab, rightLab) = (lab(lhs), lab(rhs))
        let lightnessGap = leftLab.lightness - rightLab.lightness
        let redGreenGap = leftLab.redGreenAxis - rightLab.redGreenAxis
        let yellowBlueGap = leftLab.yellowBlueAxis - rightLab.yellowBlueAxis
        return sqrt(pow(lightnessGap, 2) + pow(redGreenGap, 2) + pow(yellowBlueGap, 2))
    }

    /// sRGB → linear → XYZ (D65) → Lab.
    private static func lab(_ rgb: RGB) -> LabColor {
        let xyzColor = xyz(rgb)
        let xCurve = labCurve(xyzColor.xComponent / referenceX)
        let yCurve = labCurve(xyzColor.yComponent / referenceY)
        let zCurve = labCurve(xyzColor.zComponent / referenceZ)
        return LabColor(
            lightness: 116 * yCurve - 16, redGreenAxis: 500 * (xCurve - yCurve), yellowBlueAxis: 200 * (yCurve - zCurve)
        )
    }

    private static func xyz(_ rgb: RGB) -> XYZColor {
        let (red, green, blue) = (linear(rgb.red), linear(rgb.green), linear(rgb.blue))
        return XYZColor(
            xComponent: red * 0.4124564 + green * 0.3575761 + blue * 0.1804375,
            yComponent: red * 0.2126729 + green * 0.7151522 + blue * 0.0721750,
            zComponent: red * 0.0193339 + green * 0.1191920 + blue * 0.9503041)
    }

    private static func linear(_ channel: Double) -> Double {
        channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
    }

    /// The Lab nonlinearity (companding) function.
    private static func labCurve(_ ratio: Double) -> Double {
        ratio > pow(6.0 / 29, 3) ? pow(ratio, 1.0 / 3) : (1.0 / 3) * pow(29.0 / 6, 2) * ratio + 4.0 / 29
    }

    private static let referenceX = 0.9505
    private static let referenceY = 1.0
    private static let referenceZ = 1.0890
}
