import Foundation
import Observation
import OmakaseStore

/// The task editor's state (#218): a draft against the task as it was
/// opened. The save is injected, so the app queues it through the outbox
/// and tests record it.
///
///     let editor = TaskEditorModel(draft: TaskDraft(record: record), today: day, actions: .init { … })
@Observable
@MainActor
public final class TaskEditorModel {
    public struct Actions {
        let save: (TaskEdit) -> Void

        public init(save: @escaping (TaskEdit) -> Void) { self.save = save }
    }

    public var draft: TaskDraft
    public let original: TaskDraft
    @ObservationIgnored private let actions: Actions
    @ObservationIgnored private let today: String
    @ObservationIgnored private let calendar: Calendar

    public init(draft: TaskDraft, today: String, calendar: Calendar = .current, actions: Actions) {
        (self.draft, original, self.today) = (draft, draft, today)
        (self.calendar, self.actions) = (calendar, actions)
    }

    public var changes: TaskEdit { draft.changes(from: original) }

    /// A non-blank title, and something to save.
    public var canSave: Bool { !draft.trimmedTitle.isEmpty && !changes.isEmpty }

    /// Hands the changes to the save action; false, and nothing saved, when it can't.
    @discardableResult
    public func save() -> Bool {
        guard canSave else { return false }
        actions.save(changes)
        return true
    }

    /// The minutes field: zero or less is no estimate.
    public var estimate: Int? {
        get { draft.estimate }
        set { draft.estimate = newValue.flatMap { $0 > 0 ? $0 : nil } }
    }

    /// The stepper's value: no estimate reads as 0.
    public var estimateMinutes: Int {
        get { draft.estimate ?? 0 }
        set { estimate = newValue }
    }

    /// The "Kind" row's chip selection (spec §4, S5 #258).
    public var area: TaskArea { draft.filing.area }

    /// The "Kind" row's parent menu (spec §4, S5 #258); nil is "no parent".
    public var parent: TaskParent? { draft.filing.parent }

    /// Picks a kind (a chip), dropping a parent that no longer fits it —
    /// the same rule capture's `CaptureModel` uses (`TaskFiling.choosing`).
    public func choose(_ area: TaskArea) {
        draft.filing = TaskFiling.choosing(area, keeping: draft.filing.parent)
    }

    /// Picks a parent, or none, and the kind it implies (spec §1).
    public func choose(parent: TaskParent?) {
        draft.filing = TaskFiling(area: draft.filing.area, parent: parent)
    }

    /// The due date toggle: on starts from today, off clears it.
    public var hasDueDate: Bool {
        get { draft.dueDay != nil }
        set { draft.dueDay = newValue ? (draft.dueDay ?? today) : nil }
    }

    /// The date picker's value; the day it names is what is saved.
    public var dueDate: Date {
        get { DayString.date(draft.dueDay ?? today, calendar: calendar) ?? .now }
        set { draft.dueDay = DayString.format(newValue, calendar: calendar) }
    }
}
