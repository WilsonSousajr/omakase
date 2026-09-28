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
        title: "Draft essay", notes: "", priority: "medium", estimate: 30, dueDay: "2026-03-09",
        filing: TaskFiling(area: .work, parent: nil))

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
                == TaskDraft(
                    title: "Essay", notes: "Cite", priority: "high", estimate: 20, dueDay: "2026-03-10",
                    filing: TaskFiling(area: .work, parent: nil)))
    }

    @Test func theFourPrioritiesAreOfferedInOrder() {
        #expect(TaskDraft.priorities == ["low", "medium", "high", "urgent"])
    }

    // MARK: The draft starts from the record's filing (S5, #258)

    @Test func theDraftStartsFromTheRecordsFiling() {
        let record = TaskRecord(
            id: "t1", title: "Essay", filing: TaskFiling(area: .study, parent: .discipline("d1")))
        #expect(TaskDraft(record: record).filing == TaskFiling(area: .study, parent: .discipline("d1")))
    }

    // MARK: Re-filing in the editor (S5, #258)

    @Test func anUntouchedEditorsChangesHaveNoFiling() {
        #expect(editor().changes.filing == nil)
    }

    @Test func choosingAKindYieldsAFilingChange() {
        let model = editor()
        model.choose(.study)
        #expect(model.area == .study)
        #expect(model.changes.filing == TaskFiling(area: .study, parent: nil))
    }

    @Test func choosingAParentDerivesTheKindAndYieldsAFilingChange() {
        let model = editor()
        model.choose(parent: .discipline("d1"))
        #expect(model.area == .study && model.parent == .discipline("d1"))
        #expect(model.changes.filing == TaskFiling(area: .study, parent: .discipline("d1")))
    }

    @Test func choosingAnotherKindClearsAParentThatNoLongerFits() {
        let model = editor()
        model.choose(parent: .project("p1"))
        model.choose(.study)
        #expect(model.area == .study && model.parent == nil)
        #expect(model.changes.filing == TaskFiling(area: .study, parent: nil))
    }

    @Test func choosingTheSameKindKeepsAParentThatFits() {
        let model = editor()
        model.choose(parent: .project("p1"))
        model.choose(.work)
        #expect(model.parent == .project("p1"))
    }

    @Test func returningToTheOriginalFilingYieldsNoChange() {
        let model = editor()
        model.choose(.study)
        model.choose(.work)
        #expect(model.changes.filing == nil)
    }

    @Test func aFilingChangeAloneCanBeSaved() {
        let model = editor()
        model.choose(.life)
        #expect(model.canSave)
        #expect(model.save())
        #expect(recorder.saved == [TaskEdit(filing: TaskFiling(area: .life, parent: nil))])
    }
}
