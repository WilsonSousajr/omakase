import OmakaseStore
import Testing

@testable import OmakaseFeatures

/// A chip's kind is a mark, not a fill (glass-pass §1, #283): S4's coloured
/// border and tint are gone, and only the chosen chip shows its kind, as a dot.
struct KindChipTests {
    @Test func onlyTheChosenChipWearsItsKindDotIssue283() {
        for selection in TaskArea.allCases {
            for area in TaskArea.allCases {
                let expected = area == selection ? KindTint.token(for: area) : nil
                #expect(KindChip.dot(for: area, selection: selection) == expected)
            }
        }
    }

    /// The dot is a small mark beside the label, as the spec draws it.
    @Test func theDotIsSixPointsIssue283() {
        #expect(ControlMetrics.markDot == 6)
    }
}
