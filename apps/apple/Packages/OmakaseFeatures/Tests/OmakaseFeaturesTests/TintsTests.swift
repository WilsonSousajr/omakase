import SwiftUI
import Testing

@testable import OmakaseFeatures

struct TintsTests {
    @Test func eachTimerPhaseHasItsOwnTint() {
        #expect(TimerPhase.focus.tint == Palette.shu)
        #expect(TimerPhase.shortBreak.tint == Palette.matcha)
        #expect(TimerPhase.longBreak.tint == Palette.indigo)
    }

    @Test func knownPrioritiesMapToTheirMarks() {
        #expect(PriorityMark.color(for: "low") == PriorityMark.low)
        #expect(PriorityMark.color(for: "medium") == PriorityMark.medium)
        #expect(PriorityMark.color(for: "high") == PriorityMark.high)
        #expect(PriorityMark.color(for: "urgent") == PriorityMark.urgent)
    }

    /// The server may add a priority the cache has never seen (M2 plan, Review Focus 5).
    @Test func unknownPriorityIsNeutral() {
        #expect(PriorityMark.color(for: "someday") == Palette.inkMuted)
    }

    /// Only a priority that says something beyond the default shows its pill
    /// (spec §8): Medium, unknown and absent priorities carry none.
    @Test func showsInRowIsTrueOnlyForLowHighAndUrgent() {
        #expect(PriorityMark.showsInRow("low"))
        #expect(PriorityMark.showsInRow("high"))
        #expect(PriorityMark.showsInRow("urgent"))
        #expect(!PriorityMark.showsInRow("medium"))
        #expect(!PriorityMark.showsInRow(""))
        #expect(!PriorityMark.showsInRow("someday"))
    }

    @Test func scalesAreOnTheFourPointGrid() {
        let steps = [Spacing.tiny, Spacing.small, Spacing.medium, Spacing.large, Spacing.xLarge, Spacing.xxLarge]
        #expect(steps == [4, 8, 12, 16, 24, 32])
        #expect([Radius.small, Radius.medium, Radius.large] == [8, 12, 16])
        #expect(WindowSize.minimum == CGSize(width: 520, height: 420))
    }

    @Test func typeScaleIsDistinct() {
        let fonts = [TypeScale.display, TypeScale.title, TypeScale.headline, TypeScale.body, TypeScale.caption]
        #expect(Set(fonts).count == fonts.count)
        #expect(TypeScale.sectionLabel != TypeScale.caption)
    }

    /// Sentence case, not the web's tracked all-caps (M9 spec §8, decided
    /// with the user #262): no uppercase transform, still muted.
    @Test @MainActor func sectionLabelIsSentenceCaseAndMuted() {
        let label = String(describing: Text("Today").sectionLabel())
        #expect(!label.contains("uppercase"))
        #expect(label.contains("customDynamic"))
    }
}
