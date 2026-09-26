import Testing

@testable import OmakaseFeatures

/// The timer's dial must read as a dial when idle, before any progress arc
/// is drawn.
struct FocusTimerDialTests {
    /// WCAG 1.4.11: a UI mark needs 3:1. On the hairline the track was 1.6:1
    /// (dark) and 1.4:1 (light) over the blurred ground, so at idle the dial
    /// read as a blank circle (#173).
    @Test func idleTrackIsVisibleIssue173() {
        for dark in [true, false] {
            let ground = TranslucencyTests.blurred(dark: dark)
            #expect(RGB.contrast(FocusTimerView.track.side(dark: dark), ground) >= 3)
        }
    }
}
