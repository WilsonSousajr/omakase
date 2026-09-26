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
            move: { [unowned self] in calls.append("move \($0) \($1)") })
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
}
