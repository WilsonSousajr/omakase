import SwiftUI
import Testing

@testable import OmakaseFeatures

/// The window's ground is translucent: the desktop shows through the sumi
/// tint. The user chose 50% for clearly visible transparency (#170), knowing
/// text on the bare ground gets hard to read over a bright, unblurred window
/// directly behind (main text ~2.9:1). So legibility is checked over a
/// blurred desktop, which the behind-window material averages to about
/// mid-grey; text on cards and rows sits on the opaque `surface`.
struct TranslucencyTests {
    static let sides = [true, false]  // dark first

    @Test func compositingIsALinearBlendInSRGB() {
        let half = RGB(0x000000).composited(over: RGB(0xFFFFFF), opacity: 0.5)
        #expect(abs(half.red - 0.5) < 1e-9)
        #expect(RGB(0x123456).composited(over: RGB(0xFFFFFF), opacity: 1) == RGB(0x123456))
    }

    static func blurred(dark: Bool) -> RGB {
        Palette.background.side(dark: dark).composited(over: RGB(0x808080), opacity: Translucency.window)
    }

    /// Until #170 this held over an unblurred white (dark) or black (light)
    /// desktop; at the 50% the user chose that is ~2.9:1, a trade-off they
    /// accepted for visible transparency.
    @Test func inkReadsOverABlurredDesktop() {
        for dark in Self.sides {
            #expect(RGB.contrast(Palette.ink.side(dark: dark), Self.blurred(dark: dark)) >= 4.5)
        }
    }

    /// The user asked for clearly visible transparency (#170): the desktop
    /// must show through the tint, not sit behind a near-opaque sumi.
    @Test func theDesktopClearlyShowsThroughIssue170() {
        #expect(Translucency.window <= 0.5)
    }

    /// Muted text (section and hour labels) is held to 3:1 over a blurred
    /// desktop - the material averages what is behind to about mid-grey. Over
    /// an unblurred white window it would fall to ~2:1; #170 accepted that
    /// for visible transparency (this test was "over any desktop, no blur
    /// credited" until then). Text on cards and rows is on opaque `surface`.
    @Test func mutedInkStaysVisibleOverABlurredDesktop() {
        for dark in Self.sides {
            #expect(RGB.contrast(Palette.inkMuted.side(dark: dark), Self.blurred(dark: dark)) >= 3)
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
