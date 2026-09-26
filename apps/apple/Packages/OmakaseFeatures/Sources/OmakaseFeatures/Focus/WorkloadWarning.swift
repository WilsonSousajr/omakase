import OmakaseStore

/// The Focus header's check of the day's planned minutes against the goal
/// (#177, M3.4 spec Decisions). It only reports: it never moves anything.
/// The sum is partial when some planned items carry no estimate.
///
///     WorkloadWarning(planned: 810, goal: 720, unestimatedCount: 0).text
///     // "1h 30m over your 12h goal"
public struct WorkloadWarning: Equatable, Sendable {
    public enum Level: Equatable, Sendable {
        case none
        case within(planned: Int, goal: Int)
        case over(excess: Int, goal: Int)
    }

    public let level: Level
    public let unestimatedCount: Int

    public init(planned: Int, goal: Int, unestimatedCount: Int) {
        self.unestimatedCount = unestimatedCount
        if planned == 0 && unestimatedCount == 0 {
            level = .none
        } else if planned > goal {
            level = .over(excess: planned - goal, goal: goal)
        } else {
            level = .within(planned: planned, goal: goal)
        }
    }

    /// No cached workload yet (first launch, offline) says nothing.
    public init(record: WorkloadRecord?) {
        self.init(
            planned: record?.plannedMinutes ?? 0, goal: record?.goalMinutes ?? 0,
            unestimatedCount: record?.unestimatedCount ?? 0)
    }

    public var isPartial: Bool { unestimatedCount > 0 }

    public var isOver: Bool {
        if case .over = level { return true }
        return false
    }

    /// What the header reads, or nil when there is nothing to say.
    public var text: String? {
        let sum: String
        switch level {
        case .none: return nil
        case .within(let planned, let goal): sum = "\(Self.duration(planned)) planned of \(Self.duration(goal))"
        case .over(let excess, let goal): sum = "\(Self.duration(excess)) over your \(Self.duration(goal)) goal"
        }
        return isPartial ? "\(sum) · \(unestimatedCount) without an estimate" : sum
    }

    private static func duration(_ minutes: Int) -> String {
        let (hours, rest) = minutes.quotientAndRemainder(dividingBy: 60)
        guard hours > 0 else { return "\(rest)m" }
        return rest == 0 ? "\(hours)h" : "\(hours)h \(rest)m"
    }
}
