import Foundation
import OmakaseStore

/// One task as Focus shows it: a value copy of its record, so the board can
/// be built, sorted and tested without SwiftData.
///
///     let card = FocusCard(record: taskRecord)
public struct FocusCard: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let priority: String
    public let minutes: Int?
    public let isCompleted: Bool
    public let kanbanStatus: String
    public let scheduledDay: String?
    public let dueDay: String?
    public let isCarriedOver: Bool

    public init(
        id: String, title: String, priority: String, minutes: Int?, isCompleted: Bool, kanbanStatus: String,
        scheduledDay: String?, dueDay: String?, isCarriedOver: Bool
    ) {
        (self.id, self.title, self.priority, self.minutes) = (id, title, priority, minutes)
        (self.isCompleted, self.kanbanStatus) = (isCompleted, kanbanStatus)
        (self.scheduledDay, self.dueDay, self.isCarriedOver) = (scheduledDay, dueDay, isCarriedOver)
    }

    @MainActor
    public init(record: TaskRecord) {
        self.init(
            id: record.id, title: record.title, priority: record.priority, minutes: record.estimatedMinutes,
            isCompleted: record.isCompleted, kanbanStatus: record.kanbanStatus, scheduledDay: record.scheduledDay,
            dueDay: record.dueDay, isCarriedOver: record.isCarriedOver)
    }

    /// "from Mon 2" for a carried-over card (#129); nil otherwise.
    public func carriedFromLabel(calendar: Calendar) -> String? {
        guard isCarriedOver, let scheduledDay, let short = DayString.short(scheduledDay, calendar: calendar) else {
            return nil
        }
        return "from \(short)"
    }

    /// The deadline, shown apart from the plan day (#129): "Due Fri 13", or
    /// "Overdue" once it has passed; nil when it is the plan day or absent.
    public func dueLabel(today: String, calendar: Calendar) -> String? {
        guard let dueDay, dueDay != scheduledDay else { return nil }
        guard dueDay >= today else { return "Overdue" }
        return DayString.short(dueDay, calendar: calendar).map { "Due \($0)" }
    }
}
