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
}
