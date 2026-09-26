import OmakaseStore

/// The day as the review sums it (M3.4 spec §2): what was planned, what got
/// done and how long it was estimated to take, and what is left open.
///
/// Actual minutes are not summed: the store keeps no per-task actual time
/// (`TaskRecord` has no `actualMinutes`), so the review compares nothing it
/// would have to guess.
///
///     let summary = ReviewSummary(cards: todaysCards, day: "2026-03-07")
///     summary.doneCount   // 3
public struct ReviewSummary: Equatable, Sendable {
    /// Tasks scheduled on the day, done or not. A carried-over task belongs
    /// to the day it was planned for, as the workload counts it (#128).
    public let plannedCount: Int
    public let doneCount: Int
    /// The estimates of the done tasks that have one.
    public let doneEstimatedMinutes: Int
    /// Done tasks with no estimate, so the sum can say it is partial.
    public let doneUnestimatedCount: Int
    /// Open tasks, carried-over first, in Focus's order: what the rollover acts on.
    public let unfinished: [FocusCard]

    @MainActor
    public init(records: [TaskRecord], day: String) { self.init(cards: records.map(FocusCard.init), day: day) }

    public init(cards: [FocusCard], day: String) {
        let board = FocusBoard(cards: cards)
        plannedCount = cards.filter { $0.scheduledDay == day }.count
        doneCount = board.done.count
        doneEstimatedMinutes = board.done.compactMap(\.minutes).reduce(0, +)
        doneUnestimatedCount = board.done.filter { $0.minutes == nil }.count
        unfinished = board.carriedOver + board.inProgress + board.toDo
    }

    /// "3 of 5 done".
    public var doneLabel: String { "\(doneCount) of \(plannedCount) done" }

    /// "1h 15m estimated", partial when some done tasks had no estimate; nil
    /// when nothing is done.
    public var estimateLabel: String? {
        guard doneCount > 0 else { return nil }
        let sum = "\(Self.duration(doneEstimatedMinutes)) estimated"
        return doneUnestimatedCount == 0 ? sum : "\(sum), \(doneUnestimatedCount) without an estimate"
    }

    private static func duration(_ minutes: Int) -> String {
        let (hours, rest) = minutes.quotientAndRemainder(dividingBy: 60)
        guard hours > 0 else { return "\(rest)m" }
        return rest == 0 ? "\(hours)h" : "\(hours)h \(rest)m"
    }
}
