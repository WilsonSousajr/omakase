import Foundation
import OmakaseStore
import Testing

@testable import OmakaseFeatures

/// A named fake for the editor's save: records each edit it was handed.
@MainActor
final class RecordingEditorSaves {
    private(set) var saved: [TaskEdit] = []

    var actions: TaskEditorModel.Actions {
        TaskEditorModel.Actions(save: { [unowned self] in saved.append($0) })
    }
}

/// The task editor (#218): a draft against the task as it was opened, and
/// the edit that is saved is only what differs.
@MainActor
struct TaskEditorModelTests {
    let recorder = RecordingEditorSaves()
    let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()
    let original = TaskDraft(
        title: "Draft essay", notes: "", priority: "medium", estimate: 30, dueDay: "2026-03-09")

    func editor() -> TaskEditorModel {
        TaskEditorModel(draft: original, today: "2026-03-07", calendar: utc, actions: recorder.actions)
    }

    @Test func anUntouchedDraftHasNoChangesAndCannotBeSaved() {
        let model = editor()
        #expect(model.changes.isEmpty && !model.canSave)
        #expect(!model.save() && recorder.saved.isEmpty)
    }

    @Test func theChangesAreOnlyWhatDiffersWithTheTitleTrimmed() {
        var draft = original
        (draft.title, draft.priority, draft.notes) = ("  Final essay \n", "urgent", "Two sources")
        #expect(
            draft.changes(from: original) == TaskEdit(title: "Final essay", notes: "Two sources", priority: "urgent"))
    }

    @Test func aTitleThatOnlyGainedWhitespaceIsNotAChange() {
        var draft = original
        draft.title = "Draft essay  "
        #expect(draft.changes(from: original).isEmpty)
    }

    @Test func clearingTheEstimateAndDueDateAreClears() {
        var draft = original
        (draft.estimate, draft.dueDay) = (nil, nil)
        #expect(draft.changes(from: original) == TaskEdit(estimate: .clear, dueDay: .clear))
    }

    @Test func settingTheEstimateAndDueDateAreSets() {
        var draft = original
        (draft.estimate, draft.dueDay) = (45, "2026-03-12")
        #expect(draft.changes(from: original) == TaskEdit(estimate: .set(45), dueDay: .set("2026-03-12")))
    }

    @Test func aBlankTitleCannotBeSavedEvenWithOtherChanges() {
        let model = editor()
        (model.draft.title, model.draft.priority) = ("   ", "high")
        #expect(!model.canSave && !model.save() && recorder.saved.isEmpty)
    }

    @Test func savingHandsTheChangesToTheAction() {
        let model = editor()
        model.draft.priority = "high"
        #expect(model.save())
        #expect(recorder.saved == [TaskEdit(priority: "high")])
    }

    @Test func anEstimateOfZeroOrLessIsNoEstimate() {
        let model = editor()
        model.estimate = 0
        #expect(model.draft.estimate == nil)
        model.estimateMinutes = -5
        #expect(model.draft.estimate == nil && model.estimateMinutes == 0)
        model.estimateMinutes = 25
        #expect(model.draft.estimate == 25 && model.estimate == 25)
    }

    @Test func turningTheDueDateOffClearsItAndOnStartsFromToday() {
        let model = editor()
        model.hasDueDate = false
        #expect(model.draft.dueDay == nil && !model.hasDueDate)
        model.hasDueDate = true
        #expect(model.draft.dueDay == "2026-03-07")
    }

    @Test func theDueDateReadsAndWritesTheDay() throws {
        let model = editor()
        #expect(DayString.format(model.dueDate, calendar: utc) == "2026-03-09")
        model.dueDate = try #require(DayString.date("2026-03-20", calendar: utc))
        #expect(model.draft.dueDay == "2026-03-20")
    }

    @Test func aDraftIsReadFromTheRecord() {
        let record = TaskRecord(id: "t1", title: "Essay", priority: "high")
        (record.notes, record.estimatedMinutes, record.dueDay) = ("Cite", 20, "2026-03-10")
        #expect(
            TaskDraft(record: record)
                == TaskDraft(title: "Essay", notes: "Cite", priority: "high", estimate: 20, dueDay: "2026-03-10"))
    }

    @Test func theFourPrioritiesAreOfferedInOrder() {
        #expect(TaskDraft.priorities == ["low", "medium", "high", "urgent"])
    }
}
