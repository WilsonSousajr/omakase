import AppKit
import SwiftUI
import Testing

@testable import OmakaseFeatures

/// The palette's legibility is pinned here, so a later hue tweak cannot make
/// text unreadable without failing the gate (M2 plan, Review Focus 1-4).
struct PaletteTests {
    static let sides = [false, true]  // dark?

    @Test func textMeetsAAOnEverySurface() {
        for dark in Self.sides {
            for text in [Palette.ink, Palette.inkMuted] {
                for ground in [Palette.background, Palette.surface] {
                    #expect(RGB.contrast(text.side(dark: dark), ground.side(dark: dark)) >= 4.5)
                }
            }
        }
    }

    /// `.glassProminent` draws a white label on the tint.
    @Test func whiteLabelReadsOnShu() {
        for dark in Self.sides {
            #expect(RGB.contrast(RGB(0xFFFFFF), Palette.shu.side(dark: dark)) >= 4.5)
        }
    }

    /// WCAG 1.4.11: a UI mark (timer ring, priority mark) needs 3:1.
    @Test func accentsAreVisibleOnBackground() {
        for dark in Self.sides {
            for accent in [Palette.shu, Palette.matcha, Palette.indigo] {
                #expect(RGB.contrast(accent.side(dark: dark), Palette.background.side(dark: dark)) >= 3)
            }
        }
    }

    @Test func bridgeResolvesPerAppearance() {
        #expect(resolved(Palette.shu, .aqua) == Palette.shu.light)
        #expect(resolved(Palette.shu, .darkAqua) == Palette.shu.dark)
    }

    /// Resolving a SwiftUI `Color` in a headless test process hangs, so the
    /// appearance switch is pinned on the NSColor above; this checks `.color`
    /// wraps it rather than a fixed colour.
    @Test func swiftUIColorWrapsTheDynamicColor() {
        #expect(String(describing: Palette.ink.color).contains("customDynamic"))
    }

    private func resolved(_ token: DesignColor, _ name: NSAppearance.Name) -> RGB? {
        var result: RGB?
        NSAppearance(named: name)?.performAsCurrentDrawingAppearance {
            guard let srgb = token.nsColor.usingColorSpace(.sRGB) else { return }
            result = RGB(hex(srgb.redComponent) << 16 | hex(srgb.greenComponent) << 8 | hex(srgb.blueComponent))
        }
        return result
    }

    private func hex(_ component: CGFloat) -> UInt32 { UInt32((component * 255).rounded()) }
}
