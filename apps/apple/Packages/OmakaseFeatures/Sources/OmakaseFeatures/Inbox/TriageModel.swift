import Foundation
import Observation
import OmakaseStore

/// Triaging a list of tasks (#225, #259): the Inbox's tasks with no date -
/// which capture's ⌘⏎ puts here (IDEA §17) - or a place's open ones. Each
/// one is scheduled, done, edited or deleted; the writes go through the
/// outbox like Focus's, so triage works offline. The Inbox and a place
/// list share this one model, so they act on a task the same way (spec §5).
///
///     let triage = TriageModel(actions: actions) { FocusDay().today }
///     triage.schedule(id, .tomorrow)
@Observable
@MainActor
public final class TriageModel {
    public struct Actions {
        /// The task and its new day; the Inbox never unschedules.
        let schedule: (String, String?) -> Void
        let toggle: (String) -> Void
        let delete: (String) -> Void
        let edit: (String, TaskEdit) -> Void

        public init(
            schedule: @escaping (String, String?) -> Void, toggle: @escaping (String) -> Void,
            delete: @escaping (String) -> Void, edit: @escaping (String, TaskEdit) -> Void
        ) {
            (self.schedule, self.toggle, self.delete, self.edit) = (schedule, toggle, delete, edit)
        }
    }

    /// The task the editor sheet shows, if any.
    public var editingID: String?
    /// A delete waiting for its confirmation.
    public private(set) var deletingID: String?

    @ObservationIgnored private let actions: Actions
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let today: () -> String

    public init(actions: Actions, calendar: Calendar = .current, today: @escaping () -> String) {
        (self.actions, self.calendar, self.today) = (actions, calendar, today)
    }

    public func schedule(_ id: String, _ option: RescheduleOption) {
        actions.schedule(id, option.day(from: today(), calendar: calendar))
    }

    public func complete(_ id: String) { actions.toggle(id) }

    public func askToDelete(_ id: String) { deletingID = id }

    public func cancelDelete() { deletingID = nil }

    public func confirmDelete() {
        guard let id = deletingID else { return }
        deletingID = nil
        actions.delete(id)
    }

    public func beginEditing(_ id: String) { editingID = id }

    public func saveEdit(_ id: String, _ changes: TaskEdit) { actions.edit(id, changes) }

    /// "File under ▸" in the row's action menu (spec §4, S5 #258): the same
    /// write path as an editor save, so re-filing works offline too.
    public func refile(_ id: String, to filing: TaskFiling) { actions.edit(id, TaskEdit(filing: filing)) }

    /// The sidebar's count; SwiftUI hides a zero badge.
    public static func badge(count: Int) -> Int { max(count, 0) }
}
