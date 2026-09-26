import Foundation
import OmakaseStore
import SwiftData
import Testing

@testable import OmakaseFeatures

@MainActor
struct FocusBoardTests {
    func record(
        _ title: String, _ priority: String = "medium", done: Bool = false, status: String = "todo",
        carried: Bool = false
    ) -> TaskRecord {
        let record = TaskRecord(id: UUID().uuidString, title: title, priority: priority, isCompleted: done)
        (record.kanbanStatus, record.isCarriedOver) = (done ? "done" : status, carried)
        return record
    }

    // Ported unchanged from TodayModelTests (M1): Today's order is Focus's order.
    @Test func incompleteFirstThenPriorityThenTitle() {
        let cards = FocusBoard.ordered(
            [
                record("b", "low"), record("done", "urgent", done: true), record("a", "low"), record("z", "urgent"),
            ].map(FocusCard.init))
        #expect(cards.map(\.title) == ["z", "a", "b", "done"])
    }

    @Test func anUnknownPrioritySortsLast() {
        let cards = FocusBoard.ordered([record("odd", "someday"), record("low one", "low")].map(FocusCard.init))
        #expect(cards.map(\.title) == ["low one", "odd"])
    }

    @Test func sectionsFollowTheKanbanStatus() {
        let board = FocusBoard(records: [
            record("todo"), record("doing", status: "in_progress"), record("finished", done: true),
        ])
        #expect(board.toDo.map(\.title) == ["todo"])
        #expect(board.inProgress.map(\.title) == ["doing"])
        #expect(board.done.map(\.title) == ["finished"])
        #expect(board.carriedOver.isEmpty)
    }

    @Test func carriedOverIsASectionInTheList() {
        let board = FocusBoard(records: [record("today"), record("yesterday's", carried: true)])
        #expect(board.carriedOver.map(\.title) == ["yesterday's"])
        #expect(board.toDo.map(\.title) == ["today"])
    }

    @Test func carriedOverJoinsToDoOnTheBoard() {
        let board = FocusBoard(records: [record("today", "low"), record("yesterday's", "high", carried: true)])
        let columns = board.columns
        #expect(columns.map(\.status) == ["todo", "in_progress", "done"])
        #expect(columns[0].cards.map(\.title) == ["yesterday's", "today"])
    }

    @Test func aCompletedCarriedTaskLeavesTheCarriedSection() {
        let board = FocusBoard(records: [record("yesterday's", done: true, carried: true)])
        #expect(board.carriedOver.isEmpty && board.done.map(\.title) == ["yesterday's"])
    }

    @Test func aCardCarriesWhatTheBoardShows() {
        let source = record("Essay", "high", carried: true)
        (source.estimatedMinutes, source.dueDay, source.scheduledDay) = (45, "2026-03-09", "2026-03-06")
        let card = FocusCard(record: source)
        #expect(card.minutes == 45 && card.dueDay == "2026-03-09" && card.scheduledDay == "2026-03-06")
        #expect(card.isCarriedOver && card.priority == "high" && !card.isCompleted)
    }
}
