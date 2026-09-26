import SwiftUI
import Testing

@testable import OmakaseFeatures

/// Buttons are monochrome, like the web client's: the user rejected shu on
/// buttons. The primary action is an inverted ink pill.
@MainActor
struct ButtonStyleTests {
    @Test func primaryLabelReadsOnItsPill() {
        for dark in [true, false] {
            let pill = PrimaryButtonStyle.fill.side(dark: dark)
            #expect(RGB.contrast(PrimaryButtonStyle.label.side(dark: dark), pill) >= 4.5)
        }
    }

    @Test func primaryIsInkNotShu() {
        #expect(PrimaryButtonStyle.fill == Palette.ink)
        #expect(PrimaryButtonStyle.fill != Palette.shu)
    }

    @Test func primaryRendersAsSwiftUI() {
        let renderer = ImageRenderer(content: Button("Sign in") {}.buttonStyle(.primary))
        #expect(renderer.cgImage != nil)
    }
}
