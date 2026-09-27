import OmakaseStore

/// The profile as Settings edits it (#228). A reminder is nil when it is off.
public struct ProfileValues: Equatable, Sendable {
    public var workMinutes: Int
    public var shortBreakMinutes: Int
    public var longBreakMinutes: Int
    public var beforeLongBreak: Int
    public var workGoalHours: Double
    public var studyGoalHours: Double
    public var blockReminderMinutes: Int?
    /// "HH:MM:SS" in the user's day.
    public var shutdownReminderTime: String?
    /// "monday" or "sunday".
    public var weekStartsOn: String
    /// Shown, not edited: the Mac dates with its own clock (M5 spec, Decisions).
    public var timezone: String

    public init(
        workMinutes: Int, shortBreakMinutes: Int, longBreakMinutes: Int, beforeLongBreak: Int, workGoalHours: Double,
        studyGoalHours: Double, blockReminderMinutes: Int?, shutdownReminderTime: String?, weekStartsOn: String,
        timezone: String
    ) {
        (self.workMinutes, self.shortBreakMinutes, self.longBreakMinutes) = (
            workMinutes, shortBreakMinutes, longBreakMinutes
        )
        (self.beforeLongBreak, self.workGoalHours, self.studyGoalHours) = (
            beforeLongBreak, workGoalHours, studyGoalHours
        )
        (self.blockReminderMinutes, self.shutdownReminderTime) = (blockReminderMinutes, shutdownReminderTime)
        (self.weekStartsOn, self.timezone) = (weekStartsOn, timezone)
    }

    @MainActor
    public init(record: ProfileRecord) {
        self.init(
            workMinutes: record.workMinutes, shortBreakMinutes: record.shortBreakMinutes,
            longBreakMinutes: record.longBreakMinutes, beforeLongBreak: record.beforeLongBreak,
            workGoalHours: record.workGoalHours, studyGoalHours: record.studyGoalHours,
            blockReminderMinutes: record.blockReminderMinutes, shutdownReminderTime: record.shutdownReminderTime,
            weekStartsOn: record.weekStartsOn, timezone: record.timezone)
    }

    /// What `self` changes from `saved`, field by field.
    public func change(from saved: ProfileValues) -> ProfileChange {
        var change = ProfileChange()
        change.workMinutes = differs(\.workMinutes, saved)
        change.shortBreakMinutes = differs(\.shortBreakMinutes, saved)
        change.longBreakMinutes = differs(\.longBreakMinutes, saved)
        change.beforeLongBreak = differs(\.beforeLongBreak, saved)
        change.workGoalHours = differs(\.workGoalHours, saved)
        change.studyGoalHours = differs(\.studyGoalHours, saved)
        change.weekStartsOn = differs(\.weekStartsOn, saved)
        change.blockReminderMinutes = clearable(\.blockReminderMinutes, saved)
        change.shutdownReminderTime = clearable(\.shutdownReminderTime, saved)
        return change
    }

    private func differs<Value: Equatable>(_ field: KeyPath<Self, Value>, _ saved: Self) -> Value? {
        self[keyPath: field] == saved[keyPath: field] ? nil : self[keyPath: field]
    }

    private func clearable<Value: Equatable & Sendable>(
        _ field: KeyPath<Self, Value?>, _ saved: Self
    ) -> ProfileChange.Clearable<Value>? {
        guard self[keyPath: field] != saved[keyPath: field] else { return nil }
        return self[keyPath: field].map { .set($0) } ?? .clear
    }
}
