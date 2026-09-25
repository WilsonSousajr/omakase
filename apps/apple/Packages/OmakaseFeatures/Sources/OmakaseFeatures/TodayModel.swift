import OmakaseStore

public struct TodayRow: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let isCompleted: Bool
    public let priority: String
}

/// How the Today list orders what it shows.
///
///     let rows = TodayModel.rows(records)
public enum TodayModel {
    private static let rank = ["urgent": 0, "high": 1, "medium": 2, "low": 3]

    /// Incomplete first, then priority (urgent to low, unknown last), then title.
    @MainActor
    public static func rows(_ records: [TaskRecord]) -> [TodayRow] {
        records.map { TodayRow(id: $0.id, title: $0.title, isCompleted: $0.isCompleted, priority: $0.priority) }
            .sorted(by: precedes)
    }

    private static func precedes(_ lhs: TodayRow, _ rhs: TodayRow) -> Bool {
        if lhs.isCompleted != rhs.isCompleted { return !lhs.isCompleted }
        let (left, right) = (rank[lhs.priority] ?? 4, rank[rhs.priority] ?? 4)
        return left != right ? left < right : lhs.title < rhs.title
    }
}
