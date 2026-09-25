import SwiftUI
import Testing

@testable import OmakaseFeatures

struct TintsTests {
    @Test func eachTimerPhaseHasItsOwnTint() {
        #expect(TimerPhase.focus.tint == Palette.shu)
        #expect(TimerPhase.shortBreak.tint == Palette.matcha)
        #expect(TimerPhase.longBreak.tint == Palette.ai)
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

    @Test func scalesAreOnTheFourPointGrid() {
        let steps = [Spacing.xs, Spacing.s, Spacing.m, Spacing.l, Spacing.xl, Spacing.xxl]
        #expect(steps == [4, 8, 12, 16, 24, 32])
        #expect([Radius.small, Radius.medium, Radius.large] == [8, 12, 16])
        #expect(WindowSize.minimum == CGSize(width: 520, height: 420))
    }

    @Test func typeScaleIsDistinct() {
        let fonts = [TypeScale.display, TypeScale.title, TypeScale.headline, TypeScale.body, TypeScale.caption]
        #expect(Set(fonts).count == fonts.count)
        #expect(TypeScale.sectionLabel != TypeScale.caption)
        #expect(TypeScale.displayTracking > TypeScale.sectionLabelTracking)
    }
}
