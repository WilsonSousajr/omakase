import SwiftUI
import Testing

@testable import OmakaseFeatures

/// Buttons are monochrome, like the web client's: the user rejected shu on
/// buttons. The primary action is an inverted ink pill; every other button
/// is a glass capsule of the same height, and an icon button a glass circle
/// (glass-pass §1, #283).
@MainActor
struct ButtonStyleTests {
    static let sides = [true, false]  // dark first

    @Test func primaryLabelReadsOnItsPill() {
        for dark in Self.sides {
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

    /// The height is the primary pill's own from before #283 (a headline
    /// line and `Spacing.small` above and below), so Complete keeps its size
    /// and everything beside it grows to match.
    @Test func theControlHeightIsThePrimaryPillsOwnIssue283() {
        let pill = Text("Complete").font(TypeScale.headline).padding(.vertical, Spacing.small)
        #expect(Self.size(of: pill).height == ControlMetrics.height)
    }

    /// Focus's Complete was a capsule while Edit… and Reschedule beside it
    /// were shorter rounded rectangles, which read as loose (#283).
    @Test func primaryAndSecondaryShareTheControlHeightIssue283() {
        #expect(Self.size(of: Button("Complete") {}.buttonStyle(.primary)).height == ControlMetrics.height)
        #expect(Self.size(of: Button("Edit…") {}.buttonStyle(.secondary)).height == ControlMetrics.height)
        let repeatButton = Button("Repeat", systemImage: "repeat") {}.buttonStyle(.secondary)
        #expect(Self.size(of: repeatButton).height == ControlMetrics.height)
        let chosen = Button("Study") {}.buttonStyle(SecondaryButtonStyle(isSelected: true))
        #expect(Self.size(of: chosen).height == ControlMetrics.height)
    }

    /// A menu button (Reschedule ⌄) is the same capsule with a ⌄ after its
    /// label: under a custom button style macOS drops its own indicator, and
    /// `.menuIndicator(.visible)` does not bring it back (seen in a harness).
    @Test func aMenuCapsuleKeepsTheHeightAndAddsItsIndicatorIssue283() {
        let menu = Self.size(of: Button("Reschedule") {}.buttonStyle(SecondaryMenuButtonStyle()))
        let plain = Self.size(of: Button("Reschedule") {}.buttonStyle(.secondary))
        #expect(menu.height == ControlMetrics.height)
        #expect(menu.width > plain.width)
    }

    /// An icon button (‹ ›, the rating dots) is a circle as tall as the capsules beside it.
    @Test func anIconButtonIsACircleOfTheControlHeightIssue283() {
        let size = Self.size(of: Button("Next", systemImage: "chevron.right") {}.buttonStyle(.icon))
        #expect(size == CGSize(width: ControlMetrics.height, height: ControlMetrics.height))
    }

    /// The glass blurs what is behind it. The worst backdrop in the window
    /// is its own ground over a blurred desktop (`TranslucencyTests`):
    /// cards and panels are opaque `surface`, which ink reads on at 13.9:1.
    @Test func secondaryLabelReadsOnGlassOverTheBlurredGroundIssue283() {
        for dark in Self.sides {
            let ground = TranslucencyTests.blurred(dark: dark)
            #expect(RGB.contrast(SecondaryButtonStyle.label.side(dark: dark), ground) >= 4.5)
        }
    }

    /// A chosen chip or an on toggle adds a faint ink fill; its label still reads.
    @Test func aChosenLabelReadsOnItsInkTintIssue283() {
        for dark in Self.sides {
            let ground = TranslucencyTests.blurred(dark: dark)
            let fill = SecondaryButtonStyle.selectedFill.side(dark: dark)
            let chosen = fill.composited(over: ground, opacity: ControlMetrics.selectedFillOpacity)
            #expect(RGB.contrast(SecondaryButtonStyle.label.side(dark: dark), chosen) >= 4.5)
        }
    }

    /// Mono chrome is about kind colour, not the platform's destructive
    /// signal: "Delete block" deletes at once, with no undo, and drew in ink
    /// like its neighbours until the G1 review. Its label is red again, and
    /// never shu, which is a signal, not a button colour.
    @Test func aDestructiveButtonStaysRedIssue283() {
        #expect(SecondaryButtonStyle.labelColor(for: .destructive) == Palette.destructive)
        #expect(SecondaryButtonStyle.labelColor(for: nil) == Palette.ink)
        #expect(SecondaryButtonStyle.labelColor(for: .cancel) == Palette.ink)
        #expect(Palette.destructive != Palette.shu)
    }

    /// The red reads where the ink does: over the blurred ground, the glass's worst backdrop.
    @Test func aDestructiveLabelReadsOnGlassOverTheBlurredGroundIssue283() {
        for dark in Self.sides {
            let ground = TranslucencyTests.blurred(dark: dark)
            #expect(RGB.contrast(Palette.destructive.side(dark: dark), ground) >= 4.5)
        }
    }

    /// The Calendar overlay's switch is a capsule of the same height while on.
    @Test func anOnToggleKeepsTheControlHeightIssue283() {
        let toggle = Toggle("Calendar", isOn: .constant(true)).toggleStyle(.secondary)
        #expect(Self.size(of: toggle).height == ControlMetrics.height)
    }

    /// Mono chrome (glass-pass §1): the capsule's label and its chosen fill
    /// are ink. A dim label read as disabled on glass (#172, #213).
    @Test func secondaryIsInkNotShuIssue283() {
        #expect(SecondaryButtonStyle.label == Palette.ink)
        #expect(SecondaryButtonStyle.selectedFill == Palette.ink)
    }

    /// A glass control has no bezel change to show a press or a disabled
    /// state, so its label carries both, disabled winning.
    @Test func aGlassLabelDimsWhenPressedAndMoreWhenDisabledIssue283() {
        #expect(ControlMetrics.labelOpacity(isPressed: false, isEnabled: true) == 1)
        #expect(ControlMetrics.labelOpacity(isPressed: true, isEnabled: true) == ControlMetrics.pressedOpacity)
        #expect(ControlMetrics.labelOpacity(isPressed: true, isEnabled: false) == ControlMetrics.disabledOpacity)
        #expect(ControlMetrics.disabledOpacity < ControlMetrics.pressedOpacity)
    }

    /// The rendered size in points: the renderer's scale is 1.
    private static func size(of view: some View) -> CGSize {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        guard let image = renderer.cgImage else { return .zero }
        return CGSize(width: image.width, height: image.height)
    }
}
