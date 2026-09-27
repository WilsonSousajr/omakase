/// What a drag on Plan carries (#203). SwiftUI transfers it as a String, as
/// Kanban's cards travel, so a prefix tells a task from the column (a new
/// block) from a block on the grid (a move). Classes are never dragged.
///
///     .draggable(PlanDragPayload.block(item.id).text)   // "block:<id>"
public enum PlanDragPayload: Equatable, Sendable {
    case task(String)
    case block(String)

    /// Nil for anything but "task:<id>" or "block:<id>" with a non-empty id.
    public init?(_ text: String) {
        guard let match = text.wholeMatch(of: /(task|block):(.+)/) else { return nil }
        let id = String(match.2)
        self = match.1 == "task" ? .task(id) : .block(id)
    }

    public var text: String {
        switch self {
        case .task(let id): "task:\(id)"
        case .block(let id): "block:\(id)"
        }
    }
}
