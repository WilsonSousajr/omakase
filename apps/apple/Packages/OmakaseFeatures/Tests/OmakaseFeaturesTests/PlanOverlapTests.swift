import Testing

@testable import OmakaseFeatures

/// The blocks a placement would overlap, for the "Place anyway?" question
/// (spec M4, Decisions): other blocks on the same day only, and touching is
/// not overlapping.
struct PlanOverlapTests {
    let day = "2026-09-28"

    func item(
        _ id: String, _ start: Int, _ end: Int, kind: CalendarItem.Kind = .block, day: String = "2026-09-28"
    ) -> CalendarItem {
        CalendarItem(id: id, day: day, start: start, end: end, title: "T-\(id)", kind: kind)
    }

    @Test func aPlacementInsideABlockOverlapsIt() {
        let titles = PlanOverlap.titles(
            for: PlanPlacement(day: day, start: 615, end: 645), among: [item("a", 600, 660)])
        #expect(titles == ["T-a"])
    }

    @Test func touchingIsNotOverlapping() {
        let items = [item("before", 540, 600), item("after", 660, 720)]
        #expect(PlanOverlap.titles(for: PlanPlacement(day: day, start: 600, end: 660), among: items).isEmpty)
    }

    @Test func everyOverlappedBlockIsNamedInTimeOrder() {
        let items = [item("late", 650, 700), item("early", 590, 610), item("clear", 700, 760), item("mid", 620, 630)]
        let titles = PlanOverlap.titles(for: PlanPlacement(day: day, start: 600, end: 660), among: items)
        #expect(titles == ["T-early", "T-mid", "T-late"])
    }

    @Test func anotherDaysBlockDoesNotOverlap() {
        let items = [item("a", 600, 660, day: "2026-09-29")]
        #expect(PlanOverlap.titles(for: PlanPlacement(day: day, start: 600, end: 660), among: items).isEmpty)
    }

    @Test func classesAndSessionsAreNotAsked() {
        let items = [item("class", 600, 660, kind: .classOccurrence), item("ran", 600, 625, kind: .focusSession)]
        #expect(PlanOverlap.titles(for: PlanPlacement(day: day, start: 600, end: 660), among: items).isEmpty)
    }

    @Test func aMovedBlockDoesNotOverlapItself() {
        let items = [item("moving", 600, 660), item("other", 640, 700)]
        let titles = PlanOverlap.titles(
            for: PlanPlacement(day: day, start: 615, end: 675), among: items, excluding: "moving")
        #expect(titles == ["T-other"])
    }

    @Test func theQuestionNamesTheBlocks() {
        #expect(PlanOverlap.question(["Essay"]) == "Overlaps Essay. Place anyway?")
        #expect(PlanOverlap.question(["Essay", "Review PR"]) == "Overlaps Essay, Review PR. Place anyway?")
    }
}
