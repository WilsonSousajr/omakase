import OmakaseStore
import Testing

@testable import OmakaseFeatures

/// The day as the review sums it: what was planned, what got done, and what
/// is left for the rollover (M3.4 spec §2).
struct ReviewSummaryTests {
    let day = "2026-03-07"

    func card(
        _ id: String, minutes: Int? = nil, done: Bool = false, status: String = "todo",
        scheduled: String? = "2026-03-07",
        carried: Bool = false
    ) -> FocusCard {
        FocusCard(
            id: id, title: id, priority: "medium", minutes: minutes, isCompleted: done, kanbanStatus: status,
            scheduledDay: scheduled, dueDay: nil, isCarriedOver: carried)
    }

    @Test func plannedCountsTheTasksScheduledOnTheDay() {
        let summary = ReviewSummary(
            cards: [card("a"), card("b", done: true), card("c", scheduled: "2026-03-01")], day: day)
        #expect(summary.plannedCount == 2)
    }

    @Test func aCarriedOverTaskIsNotPartOfTheDaysPlan() {
        let summary = ReviewSummary(cards: [card("a"), card("old", scheduled: "2026-03-02", carried: true)], day: day)
        #expect(summary.plannedCount == 1)
    }

    @Test func doneCountsCompletedTasksAndTheDoneColumn() {
        let summary = ReviewSummary(cards: [card("a", done: true), card("b", status: "done"), card("c")], day: day)
        #expect(summary.doneCount == 2)
    }

    @Test func estimatedMinutesSumTheDoneTasksOnly() {
        let cards = [card("a", minutes: 30, done: true), card("b", minutes: 45, done: true), card("c", minutes: 60)]
        #expect(ReviewSummary(cards: cards, day: day).doneEstimatedMinutes == 75)
    }

    @Test func doneTasksWithNoEstimateAreCountedSoTheSumCanSayItIsPartial() {
        let cards = [card("a", minutes: 30, done: true), card("b", done: true), card("c")]
        #expect(ReviewSummary(cards: cards, day: day).doneUnestimatedCount == 1)
    }

    @Test func unfinishedListsOpenTasksCarriedOverFirst() {
        let cards = [
            card("today"), card("done", done: true), card("old", scheduled: "2026-03-02", carried: true),
            card("going", status: "in_progress"),
        ]
        #expect(ReviewSummary(cards: cards, day: day).unfinished.map(\.id) == ["old", "going", "today"])
    }

    @Test func anEmptyDaySumsToNothing() {
        let summary = ReviewSummary(cards: [], day: day)
        #expect(summary.plannedCount == 0)
        #expect(summary.doneCount == 0)
        #expect(summary.doneEstimatedMinutes == 0)
        #expect(summary.unfinished.isEmpty)
    }
}

@MainActor
struct ReviewSummaryRecordTests {
    @Test func theStoresRecordsAreSummedAsCards() {
        let records = [
            TaskRecord(id: "a", title: "A", scheduledDay: "2026-03-07", isCompleted: true),
            TaskRecord(id: "b", title: "B", scheduledDay: "2026-03-07"),
        ]
        let summary = ReviewSummary(records: records, day: "2026-03-07")
        #expect(summary.doneCount == 1)
        #expect(summary.unfinished.map(\.id) == ["b"])
    }
}
