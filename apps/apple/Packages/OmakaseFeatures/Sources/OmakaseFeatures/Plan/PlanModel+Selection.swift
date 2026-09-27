/// What Plan's detail panel shows (#217): a task, from the column or a
/// block's "Open task", or a block on the grid.
public enum PlanSelection: Equatable, Sendable {
    case task(String)
    case block(String)
}

extension PlanModel {
    /// A click on a task row or a block; nil, a click on the empty grid.
    ///
    ///     plan.select(.block(item.id))
    public func select(_ selected: PlanSelection?) { selection = selected }

    /// The block the panel shows, when a block is selected and still drawn.
    public func selectedBlock(in items: [CalendarItem]) -> CalendarItem? {
        guard case .block(let id) = selection else { return nil }
        return items.first { $0.id == id && $0.kind == .block }
    }

    /// "Open task": the panel moves from a block to its parent task. A study
    /// block has none, so the block stays selected.
    public func openTask(of block: CalendarItem) {
        guard let taskID = block.taskID else { return }
        selection = .task(taskID)
    }

    /// Clears the selection once what it names is no longer in the store:
    /// a completed task elsewhere, a deleted block, a block moved out of view.
    public func keepSelection(taskIDs: Set<String>, items: [CalendarItem]) {
        switch selection {
        case .task(let id) where !taskIDs.contains(id): selection = nil
        case .block where selectedBlock(in: items) == nil: selection = nil
        default: return
        }
    }
}
