import AppKit
import SwiftUI
import Testing

@testable import OmakaseFeatures

/// The palette's legibility is pinned here, so a later hue tweak cannot make
/// text unreadable without failing the gate (M2 plan, Review Focus 1-4).
struct PaletteTests {
    static let sides = [true, false]  // dark first

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

    /// The user chose a fully monochrome UI: the system accent (checkboxes,
    /// selection) is grey. White drawn on it must read, and it must stand
    /// out from the ground and from cards.
    @Test func greyAccentCarriesWhiteAndStandsOut() {
        for dark in Self.sides {
            let accent = Palette.accent.side(dark: dark)
            #expect(RGB.contrast(RGB(0xFFFFFF), accent) >= 4.5)
            #expect(RGB.contrast(accent, Palette.background.side(dark: dark)) >= 3)
            #expect(RGB.contrast(accent, Palette.surface.side(dark: dark)) >= 3)
        }
    }

    /// Grey, not a hue: the accent carries no more colour than the sumi
    /// neutrals it sits among (they are warm, so pure-grey would clash).
    @Test func accentIsNoMoreColourfulThanTheNeutrals() {
        let neutrals = [Palette.background, Palette.surface, Palette.ink, Palette.inkMuted, Palette.hairline]
        for dark in Self.sides {
            let warmest = neutrals.map { chroma($0.side(dark: dark)) }.max() ?? 0
            #expect(chroma(Palette.accent.side(dark: dark)) <= warmest)
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

    private func chroma(_ rgb: RGB) -> Double {
        max(rgb.red, rgb.green, rgb.blue) - min(rgb.red, rgb.green, rgb.blue)
    }

    private func hex(_ component: CGFloat) -> UInt32 { UInt32((component * 255).rounded()) }
}
