import OmakaseStore

/// The day as Focus lays it out. The list shows four sections; the Kanban
/// board shows three columns, with carried-over tasks joining To do.
///
///     let board = FocusBoard(records: todaysTasks)
public struct FocusBoard: Equatable, Sendable {
    /// A Kanban column: the status a card dropped here takes.
    public struct Column: Identifiable, Equatable, Sendable {
        public let status: String
        public let title: String
        public let cards: [FocusCard]
        public var id: String { status }
    }

    public let carriedOver: [FocusCard]
    public let toDo: [FocusCard]
    public let inProgress: [FocusCard]
    public let done: [FocusCard]

    @MainActor
    public init(records: [TaskRecord]) { self.init(cards: records.map(FocusCard.init)) }

    public init(cards: [FocusCard]) {
        let open = cards.filter { !$0.isCompleted && $0.kanbanStatus != "done" }
        carriedOver = Self.ordered(open.filter(\.isCarriedOver))
        toDo = Self.ordered(open.filter { !$0.isCarriedOver && $0.kanbanStatus != "in_progress" })
        inProgress = Self.ordered(open.filter { !$0.isCarriedOver && $0.kanbanStatus == "in_progress" })
        done = Self.ordered(cards.filter { $0.isCompleted || $0.kanbanStatus == "done" })
    }

    public var columns: [Column] {
        [
            Column(status: "todo", title: "To do", cards: Self.ordered(carriedOver + toDo)),
            Column(status: "in_progress", title: "In progress", cards: inProgress),
            Column(status: "done", title: "Done", cards: done),
        ]
    }

    /// Every card, in the list's order.
    public var cards: [FocusCard] { carriedOver + inProgress + toDo + done }

    private static let rank = ["urgent": 0, "high": 1, "medium": 2, "low": 3]

    /// Incomplete first, then priority (urgent to low, unknown last), then
    /// title: Today's order from M1, kept for Focus.
    static func ordered(_ cards: [FocusCard]) -> [FocusCard] { cards.sorted(by: precedes) }

    private static func precedes(_ lhs: FocusCard, _ rhs: FocusCard) -> Bool {
        if lhs.isCompleted != rhs.isCompleted { return !lhs.isCompleted }
        let (left, right) = (rank[lhs.priority] ?? 4, rank[rhs.priority] ?? 4)
        return left != right ? left < right : lhs.title < rhs.title
    }
}
