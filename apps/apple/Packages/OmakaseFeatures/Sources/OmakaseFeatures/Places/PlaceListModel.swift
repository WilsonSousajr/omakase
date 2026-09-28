import Observation
import OmakaseStore

/// The place shown on screen, if any (spec §5): reads it now and after each
/// catch-up while it stays shown, as `PlanModel`'s visible days do. Task
/// writes go through `TriageModel`, the same actions the Inbox uses.
///
///     let places = PlaceListModel(actions: services.placesActions())
///     places.show(.discipline("d1"))
@Observable
@MainActor
public final class PlaceListModel {
    /// What a place list asks the app for: reading one place's open tasks.
    public struct Actions {
        let refresh: (TaskPlace) -> Void

        public init(refresh: @escaping (TaskPlace) -> Void) { self.refresh = refresh }

        /// No reads: previews, and a model built before the app wires one.
        public static var none: Actions { Actions(refresh: { _ in }) }
    }

    /// The place on screen, or nil when none is.
    public private(set) var shown: TaskPlace?
    @ObservationIgnored private let actions: Actions

    public init(actions: Actions = .none) { self.actions = actions }

    /// A place came on screen: read it now, and after each catch-up while it stays shown.
    public func show(_ place: TaskPlace) {
        shown = place
        refresh()
    }

    /// The place leaves the screen: nothing is read for it until `show(_:)` names one again.
    public func hide() { shown = nil }

    /// Reads the shown place again; a no-op when none is shown.
    public func refresh() {
        guard let shown else { return }
        actions.refresh(shown)
    }

    /// A catch-up finished; the shown place is read again only while it shows.
    public func caughtUp() { refresh() }
}
