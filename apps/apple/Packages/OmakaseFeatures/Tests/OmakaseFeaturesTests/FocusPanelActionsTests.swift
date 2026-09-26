import Testing

@testable import OmakaseFeatures

/// The Focus panel's actions: Complete, the one primary, and Reschedule.
struct FocusPanelActionsTests {
    /// Left to itself, a `.menuStyle(.button)` menu draws its label in a dim
    /// grey that reads as disabled beside the Complete pill, though it works
    /// (seen in a capture of the real window, #172). It is ink, like the other
    /// glass buttons.
    @Test func rescheduleLabelIsInkIssue172() {
        #expect(FocusPanelActionsView.menuLabel == Palette.ink)
    }
}
