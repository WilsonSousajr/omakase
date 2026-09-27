import Foundation
import Observation
import OmakaseStore

/// Focus's state and actions. The writes are injected, so the app wires them
/// to the outbox (`coordinator.write { … }`) and tests record them.
///
///     let model = FocusModel(actions: .init(toggle: { … }, move: { … }))
@Observable
@MainActor
public final class FocusModel {
    public enum Layout: String, CaseIterable, Sendable {
        case list
        case kanban
    }

    /// The writes Focus asks for, by task id.
    public struct Actions {
        let toggle: (String) -> Void
        let move: (String, String) -> Void
        let reschedule: (String, String?) -> Void
        let toggleSubtask: (String) -> Void
        /// The instant to remind at, or nil to clear the reminder (#187).
        let remind: (String, Date?) -> Void
        /// The task editor's save: only the fields that changed (#218).
        let edit: (String, TaskEdit) -> Void

        public init(
            toggle: @escaping (String) -> Void, move: @escaping (String, String) -> Void,
            reschedule: @escaping (String, String?) -> Void, toggleSubtask: @escaping (String) -> Void,
            remind: @escaping (String, Date?) -> Void, edit: @escaping (String, TaskEdit) -> Void
        ) {
            (self.toggle, self.move) = (toggle, move)
            (self.reschedule, self.toggleSubtask, self.remind, self.edit) = (reschedule, toggleSubtask, remind, edit)
        }
    }

    private static let layoutKey = "focus.layout"

    public var layout: Layout {
        didSet { defaults.set(layout.rawValue, forKey: Self.layoutKey) }
    }
    public var selectedID: String?
    /// The task the editor sheet is open on, or nil when it is closed (#218).
    public var editingID: String?

    @ObservationIgnored private let actions: Actions
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored public let calendar: Calendar

    public init(actions: Actions, defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        (self.actions, self.defaults, self.calendar) = (actions, defaults, calendar)
        layout = defaults.string(forKey: Self.layoutKey).flatMap(Layout.init) ?? .kanban
    }

    public func toggle(_ id: String) { actions.toggle(id) }

    /// A card dropped on a column. Moving to Done completes the task.
    public func move(_ id: String, to status: String) { actions.move(id, status) }

    /// Moves a task to `option`'s day, counted from `today`; the backlog is nil.
    public func reschedule(_ id: String, _ option: RescheduleOption, today: String) {
        actions.reschedule(id, option.day(from: today, calendar: calendar))
    }

    public func toggleSubtask(_ id: String) { actions.toggleSubtask(id) }

    /// Sets the task's reminder to `choice`, counted from `now`; `.clear` removes it.
    public func remind(_ id: String, _ choice: ReminderChoice, now: Date = .now) {
        actions.remind(id, choice.date(from: now, calendar: calendar))
    }

    /// Opens the editor on a task (double-click, the Edit button), selecting it too.
    public func beginEditing(_ id: String) { (selectedID, editingID) = (id, id) }

    /// Return on the board: edits the selected task, if there is one.
    public func editSelected() {
        guard let selectedID else { return }
        beginEditing(selectedID)
    }

    public func saveEdit(_ id: String, _ changes: TaskEdit) {
        actions.edit(id, changes)
        editingID = nil
    }

    public func selectedCard(in board: FocusBoard) -> FocusCard? {
        board.cards.first { $0.id == selectedID }
    }

    /// Keeps the panel on a task that is still on the board; otherwise the
    /// first To do (carried-over first), or nothing.
    public func keepSelection(in board: FocusBoard) {
        guard !board.cards.contains(where: { $0.id == selectedID }) else { return }
        selectedID = board.columns.first?.cards.first?.id
    }
}
