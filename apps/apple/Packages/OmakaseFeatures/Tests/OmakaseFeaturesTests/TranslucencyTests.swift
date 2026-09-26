import SwiftUI
import Testing

@testable import OmakaseFeatures

/// The window's ground is translucent: the desktop shows through the sumi
/// tint. Text drawn straight on it must stay legible over the worst desktop,
/// pure white behind dark and pure black behind light, even before the
/// system material's blur calms it.
struct TranslucencyTests {
    static let sides = [true, false]  // dark first
    static func worstDesktop(dark: Bool) -> RGB { RGB(dark ? 0xFFFFFF : 0x000000) }

    static func ground(dark: Bool) -> RGB {
        Palette.background.side(dark: dark)
            .composited(over: worstDesktop(dark: dark), opacity: Translucency.window)
    }

    @Test func compositingIsALinearBlendInSRGB() {
        let half = RGB(0x000000).composited(over: RGB(0xFFFFFF), opacity: 0.5)
        #expect(abs(half.red - 0.5) < 1e-9)
        #expect(RGB(0x123456).composited(over: RGB(0xFFFFFF), opacity: 1) == RGB(0x123456))
    }

    @Test func inkReadsOverAnyDesktop() {
        for dark in Self.sides {
            #expect(RGB.contrast(Palette.ink.side(dark: dark), Self.ground(dark: dark)) >= 4.5)
        }
    }

    /// The user asked for clearly visible transparency (#170): the desktop
    /// must show through the tint, not sit behind a near-opaque sumi.
    @Test func theDesktopClearlyShowsThroughIssue170() {
        #expect(Translucency.window <= 0.65)
    }

    /// Muted text (section and hour labels) is held to 3:1 over a blurred
    /// desktop - the material averages what is behind to about mid-grey. Over
    /// an unblurred white window it would fall to ~2:1; #170 accepted that
    /// for visible transparency (this test was "over any desktop, no blur
    /// credited" until then). Text on cards and rows is on opaque `surface`.
    @Test func mutedInkStaysVisibleOverABlurredDesktop() {
        for dark in Self.sides {
            let blurred = Palette.background.side(dark: dark)
                .composited(over: RGB(0x808080), opacity: Translucency.window)
            #expect(RGB.contrast(Palette.inkMuted.side(dark: dark), blurred) >= 3)
        }
    }

    @Test func darkIsTheDefaultAppearance() {
        #expect(Appearance.default == .dark)
    }

    @Test func appearancesMapToColorSchemes() {
        #expect(Appearance.dark.colorScheme == .dark)
        #expect(Appearance.light.colorScheme == .light)
    }

    @Test @MainActor func windowBackgroundIsAContainerBackground() {
        #expect(String(describing: Text("Plan").omakaseWindowBackground()).contains("ContainerBackground"))
    }
}
