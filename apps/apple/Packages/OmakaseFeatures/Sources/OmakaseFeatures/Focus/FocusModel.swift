import Foundation
import Observation

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

        public init(toggle: @escaping (String) -> Void, move: @escaping (String, String) -> Void) {
            (self.toggle, self.move) = (toggle, move)
        }
    }

    private static let layoutKey = "focus.layout"

    public var layout: Layout {
        didSet { defaults.set(layout.rawValue, forKey: Self.layoutKey) }
    }
    public var selectedID: String?

    @ObservationIgnored private let actions: Actions
    @ObservationIgnored private let defaults: UserDefaults

    public init(actions: Actions, defaults: UserDefaults = .standard) {
        (self.actions, self.defaults) = (actions, defaults)
        layout = defaults.string(forKey: Self.layoutKey).flatMap(Layout.init) ?? .kanban
    }

    public func toggle(_ id: String) { actions.toggle(id) }

    /// A card dropped on a column. Moving to Done completes the task.
    public func move(_ id: String, to status: String) { actions.move(id, status) }

    /// Keeps the panel on a task that is still on the board; otherwise the
    /// first To do (carried-over first), or nothing.
    public func keepSelection(in board: FocusBoard) {
        guard !board.cards.contains(where: { $0.id == selectedID }) else { return }
        selectedID = board.columns.first?.cards.first?.id
    }
}
