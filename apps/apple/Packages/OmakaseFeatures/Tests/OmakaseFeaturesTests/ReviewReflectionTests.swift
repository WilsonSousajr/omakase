import Testing

@testable import OmakaseFeatures

/// The Review's choices (the rating's marks and the Energy levels): every one
/// reads as enabled, and only the mark says which is chosen.
struct ReviewReflectionTests {
    /// With the window active, the unchosen Energy levels drew in `inkMuted`
    /// on glass and read as disabled, though they work (seen in the real app,
    /// #213; the same class of problem as #172). Their labels are ink; the
    /// check mark and the weight carry the choice.
    @Test func unchosenEnergyLabelIsInkIssue213() {
        #expect(ReviewEnergyView.unchosenLabel == Palette.ink)
    }

    /// The rating's empty marks are the same kind of choice, so the same rule.
    @Test func emptyRatingMarkIsInkIssue213() {
        #expect(ReviewRatingView.emptyMark == Palette.ink)
    }

    /// Ink stays readable on the card it sits on, in both schemes.
    @Test func unchosenLabelsReadOnSurfaceIssue213() {
        for dark in [true, false] {
            let surface = Palette.surface.side(dark: dark)
            #expect(RGB.contrast(ReviewEnergyView.unchosenLabel.side(dark: dark), surface) >= 4.5)
            #expect(RGB.contrast(ReviewRatingView.emptyMark.side(dark: dark), surface) >= 4.5)
        }
    }
}
