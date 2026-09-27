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

    /// Opens the task editor (#218) on a task, selecting it too: a
    /// double-click on a row or a block, or Edit… in the panel.
    ///
    ///     plan.beginEditing(card.id)
    public func beginEditing(_ taskID: String) { (selection, editingID) = (.task(taskID), taskID) }

    /// Return: edits the selected task, or the selected block's task.
    public func editSelected(in items: [CalendarItem]) {
        switch selection {
        case .task(let id): beginEditing(id)
        case .block: selectedBlock(in: items)?.taskID.map { beginEditing($0) }
        case nil: return
        }
    }
}
