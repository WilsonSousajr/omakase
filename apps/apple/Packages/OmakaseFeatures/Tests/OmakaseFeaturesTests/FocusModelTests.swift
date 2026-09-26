import Foundation
import Testing

@testable import OmakaseFeatures

/// A named fake for the app's write closures: records what Focus asked for.
@MainActor
final class RecordingFocusActions {
    private(set) var calls: [String] = []

    var actions: FocusModel.Actions {
        FocusModel.Actions(
            toggle: { [unowned self] in calls.append("toggle \($0)") },
            move: { [unowned self] in calls.append("move \($0) \($1)") },
            reschedule: { [unowned self] in calls.append("reschedule \($0) \($1 ?? "backlog")") },
            toggleSubtask: { [unowned self] in calls.append("subtask \($0)") })
    }
}

@MainActor
struct FocusModelTests {
    let recorder = RecordingFocusActions()
    let defaults: UserDefaults = {
        let suite = "FocusModelTests-\(UUID())"
        return UserDefaults(suiteName: suite)!
    }()

    func card(_ id: String, status: String = "todo", done: Bool = false) -> FocusCard {
        FocusCard(
            id: id, title: id, priority: "medium", minutes: nil, isCompleted: done, kanbanStatus: status,
            scheduledDay: "2026-03-07", dueDay: nil, isCarriedOver: false)
    }

    @Test func togglingAndMovingCallTheWritesWithTheTaskID() {
        let model = FocusModel(actions: recorder.actions, defaults: defaults)
        model.toggle("t1")
        model.move("t2", to: "done")
        #expect(recorder.calls == ["toggle t1", "move t2 done"])
    }

    @Test func theLayoutDefaultsToKanbanAndPersists() {
        let first = FocusModel(actions: recorder.actions, defaults: defaults)
        #expect(first.layout == .kanban)
        first.layout = .list
        #expect(FocusModel(actions: recorder.actions, defaults: defaults).layout == .list)
    }

    @Test func aSelectionThatLeftTheBoardFallsBackToTheFirstToDo() {
        let model = FocusModel(actions: recorder.actions, defaults: defaults)
        model.selectedID = "gone"
        model.keepSelection(in: FocusBoard(cards: [card("a"), card("b", status: "in_progress")]))
        #expect(model.selectedID == "a")
    }

    @Test func aSelectionStillOnTheBoardIsKept() {
        let model = FocusModel(actions: recorder.actions, defaults: defaults)
        model.selectedID = "b"
        model.keepSelection(in: FocusBoard(cards: [card("a"), card("b", status: "in_progress")]))
        #expect(model.selectedID == "b")
    }

    @Test func anEmptyBoardSelectsNothing() {
        let model = FocusModel(actions: recorder.actions, defaults: defaults)
        model.selectedID = "gone"
        model.keepSelection(in: FocusBoard(cards: []))
        #expect(model.selectedID == nil)
    }

    @Test func reschedulingSendsTheChosenDay() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = .gmt
        let model = FocusModel(actions: recorder.actions, defaults: defaults, calendar: utc)
        model.reschedule("t1", .tomorrow, today: "2026-03-07")
        model.reschedule("t2", .backlog, today: "2026-03-07")
        #expect(recorder.calls == ["reschedule t1 2026-03-08", "reschedule t2 backlog"])
    }

    @Test func checkingASubtaskCallsItsWrite() {
        let model = FocusModel(actions: recorder.actions, defaults: defaults)
        model.toggleSubtask("s1")
        #expect(recorder.calls == ["subtask s1"])
    }

    @Test func theSelectedCardIsFoundOnTheBoard() {
        let model = FocusModel(actions: recorder.actions, defaults: defaults)
        let board = FocusBoard(cards: [card("a"), card("b")])
        model.selectedID = "b"
        #expect(model.selectedCard(in: board)?.id == "b")
        model.selectedID = nil
        #expect(model.selectedCard(in: board) == nil)
    }
}
