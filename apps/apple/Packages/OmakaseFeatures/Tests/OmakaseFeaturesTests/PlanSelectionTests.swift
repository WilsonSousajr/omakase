import Foundation
import Testing

@testable import OmakaseFeatures

/// What Plan's detail panel shows (#217): a task or a block, picked by a
/// click, moved to a block's task by "Open task", and dropped when what it
/// names leaves the store.
@MainActor
struct PlanSelectionTests {
    let recorder = PlanActionsRecorder()
    let essay = CalendarItem(
        id: "b1", day: "2026-09-26", start: 540, end: 600, title: "Essay", kind: .block, taskID: "t1")
    let study = CalendarItem(id: "b2", day: "2026-09-26", start: 660, end: 720, title: "Read", kind: .block)
    let lecture = CalendarItem(
        id: "c1", day: "2026-09-26", start: 480, end: 540, title: "Lecture", kind: .classOccurrence)

    func model() -> PlanModel { PlanModel(actions: recorder.actions) { "2026-09-26" } }

    @Test func nothingIsSelectedAtFirst() {
        #expect(model().selection == nil)
    }

    @Test func aClickSelectsATaskOrABlockAndReplacesTheLast() {
        let plan = model()
        plan.select(.task("t1"))
        #expect(plan.selection == .task("t1"))
        plan.select(.block("b1"))
        #expect(plan.selection == .block("b1"))
        plan.select(nil)
        #expect(plan.selection == nil)
    }

    @Test func theSelectedBlockIsFoundAmongTheItems() {
        let plan = model()
        #expect(plan.selectedBlock(in: [essay]) == nil)
        plan.select(.block("b1"))
        #expect(plan.selectedBlock(in: [lecture, essay]) == essay)
        plan.select(.task("t1"))
        #expect(plan.selectedBlock(in: [essay]) == nil)
    }

    @Test func openTaskSelectsTheBlocksParent() {
        let plan = model()
        plan.select(.block("b1"))
        plan.openTask(of: essay)
        #expect(plan.selection == .task("t1"))
    }

    @Test func aBlockWithoutATaskHasNoTaskToOpen() {
        let plan = model()
        plan.select(.block("b2"))
        plan.openTask(of: study)
        #expect(plan.selection == .block("b2"))
    }

    @Test func aSelectionStillInTheStoreIsKept() {
        let plan = model()
        plan.select(.block("b1"))
        plan.keepSelection(taskIDs: [], items: [essay])
        #expect(plan.selection == .block("b1"))
        plan.select(.task("t1"))
        plan.keepSelection(taskIDs: ["t1"], items: [])
        #expect(plan.selection == .task("t1"))
    }

    @Test func aSelectionThatLeftTheStoreIsCleared() {
        let plan = model()
        plan.select(.block("b1"))
        plan.keepSelection(taskIDs: ["b1"], items: [study])
        #expect(plan.selection == nil)
        plan.select(.task("t1"))
        plan.keepSelection(taskIDs: [], items: [essay])
        #expect(plan.selection == nil)
    }

    @Test func aClassIsNotASelectableBlock() {
        let plan = model()
        plan.select(.block("c1"))
        plan.keepSelection(taskIDs: [], items: [lecture])
        #expect(plan.selection == nil)
    }

    @Test func deletingTheSelectedBlockClearsTheSelection() {
        let plan = model()
        plan.select(.block("b1"))
        plan.deleteBlock("b1")
        #expect(plan.selection == nil)
        #expect(recorder.calls == ["delete b1"])
    }

    @Test func deletingAnotherBlockKeepsTheSelection() {
        let plan = model()
        plan.select(.task("t1"))
        plan.deleteBlock("b1")
        #expect(plan.selection == .task("t1"))
    }
}
