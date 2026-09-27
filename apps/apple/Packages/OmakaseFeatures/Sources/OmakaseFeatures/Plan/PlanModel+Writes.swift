import CoreGraphics

/// A drop that overlaps other blocks, held until the user places it anyway
/// or cancels (spec M4, Decisions: a warning, not a refusal).
public struct PlanPendingPlacement: Equatable, Sendable {
    public let target: PlanDragPayload
    public let placement: PlanPlacement
    public let overlaps: [String]

    public var question: String { PlanOverlap.question(overlaps) }
}

extension PlanModel {
    /// What Plan asks the app for: the visible days read (#200), block
    /// writes through the outbox (#201), by task or block id, and a class
    /// cancelled or restored on its date (#207), by occurrence id.
    public struct Actions {
        let refresh: ([String]) -> Void
        let create: (String, PlanPlacement) -> Void
        let move: (String, PlanPlacement) -> Void
        let delete: (String) -> Void
        let cancelClass: (String) -> Void
        let restoreClass: (String) -> Void

        public init(
            refresh: @escaping ([String]) -> Void, create: @escaping (String, PlanPlacement) -> Void,
            move: @escaping (String, PlanPlacement) -> Void, delete: @escaping (String) -> Void,
            cancelClass: @escaping (String) -> Void = { _ in }, restoreClass: @escaping (String) -> Void = { _ in }
        ) {
            (self.refresh, self.create, self.move, self.delete) = (refresh, create, move, delete)
            (self.cancelClass, self.restoreClass) = (cancelClass, restoreClass)
        }

        /// No reads and no writes: previews, and a model built before the app wires one.
        public static var none: Actions {
            Actions(refresh: { _ in }, create: { _, _ in }, move: { _, _ in }, delete: { _ in })
        }
    }

    /// Plan came on screen: its days are read now and after each catch-up.
    public func show() {
        setShowing(true)
        refreshRange()
    }

    public func hide() { setShowing(false) }

    public func refreshRange() { actions.refresh(visibleDays) }

    /// A catch-up finished; the range is read again only while Plan shows.
    public func caughtUp() {
        guard isShowing else { return }
        refreshRange()
    }

    /// A drag dropped on `day`'s column at `offset`: a task makes a block, a
    /// block moves. False when the drop is refused, so SwiftUI animates it back.
    public func drop(_ text: String, day: String, offset: CGFloat, items: [CalendarItem]) -> Bool {
        guard let payload = PlanDragPayload(text),
            let placement = placement(of: payload, day: day, offset: offset, items: items)
        else { return false }
        propose(payload, placement, items: items)
        return true
    }

    /// A block's bottom edge let go at `bottom`.
    public func resize(_ block: CalendarItem, bottom: CGFloat, items: [CalendarItem]) {
        guard let placement = PlanDrop.resize(block, bottom: bottom, layout: .standard) else { return }
        propose(.block(block.id), placement, items: items)
    }

    public func confirmPending() {
        guard let held = pending else { return }
        pending = nil
        write(held.target, held.placement)
    }

    public func cancelPending() { pending = nil }

    /// Deletes the block, and closes its panel if it is the one open (#217).
    public func deleteBlock(_ id: String) {
        if selection == .block(id) { selection = nil }
        actions.delete(id)
    }

    /// Cancels a class on its date, or restores a cancelled one; anything
    /// but a class is left alone.
    public func toggleCancellation(_ item: CalendarItem) {
        guard item.kind == .classOccurrence else { return }
        if item.isCancelled { actions.restoreClass(item.id) } else { actions.cancelClass(item.id) }
    }

    private func placement(
        of payload: PlanDragPayload, day: String, offset: CGFloat, items: [CalendarItem]
    ) -> PlanPlacement? {
        guard let id = payload.blockID else { return PlanDrop.create(day: day, offset: offset, layout: .standard) }
        guard let block = items.first(where: { $0.id == id && $0.kind == .block }) else { return nil }
        return PlanDrop.move(block, day: day, offset: offset, layout: .standard)
    }

    /// Writes at once unless the placement overlaps another block; a block
    /// put back where it was writes nothing.
    private func propose(_ target: PlanDragPayload, _ placement: PlanPlacement, items: [CalendarItem]) {
        let current = items.first { $0.id == target.blockID && $0.kind == .block }
        guard current.map(PlanPlacement.init(of:)) != placement else { return }
        let overlaps = PlanOverlap.titles(for: placement, among: items, excluding: target.blockID)
        guard overlaps.isEmpty else {
            pending = PlanPendingPlacement(target: target, placement: placement, overlaps: overlaps)
            return
        }
        write(target, placement)
    }

    private func write(_ target: PlanDragPayload, _ placement: PlanPlacement) {
        switch target {
        case .task(let id): actions.create(id, placement)
        case .block(let id): actions.move(id, placement)
        }
    }
}
