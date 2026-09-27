import Foundation
import Observation
import OmakaseStore

/// The Inbox (#225): tasks with no date, which capture's ⌘⏎ puts here
/// (IDEA §17). Each one is triaged to a day, done, edited or deleted; the
/// writes go through the outbox like Focus's, so the Inbox works offline.
///
///     let inbox = InboxModel(actions: actions) { FocusDay().today }
///     inbox.schedule(id, .tomorrow)
@Observable
@MainActor
public final class InboxModel {
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

    /// The sidebar's count; SwiftUI hides a zero badge.
    public static func badge(count: Int) -> Int { max(count, 0) }
}
