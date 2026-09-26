import Foundation

/// One notification to schedule. The id is stable, so re-planning replaces
/// a request rather than duplicating it.
public struct PlannedReminder: Equatable, Sendable {
    public let id: String
    public let fireDate: Date
    public let title: String
    public let body: String
}

/// What the Mac schedules for the day (M3.6 spec §2): a heads-up before each
/// time block, each task's own reminder, and the shutdown reminder. Pure, so
/// the app target only hands the plan to UserNotifications.
///
///     let plan = ReminderPlanner.plan(input)   // soonest first, at most 64
public enum ReminderPlanner {
    /// Every planned id starts with this; the scheduler owns nothing else.
    public static let idPrefix = "omakase.reminder."
    /// The system keeps at most 64 pending requests per app.
    public static let limit = 64

    /// A time block as the store holds it: the day and its "HH:MM:SS" start.
    public struct Block: Sendable {
        let id: String
        let day: String
        let startTime: String
        let title: String

        public init(id: String, day: String, startTime: String, title: String) {
            (self.id, self.day, self.startTime, self.title) = (id, day, startTime, title)
        }
    }

    public struct TaskReminder: Sendable {
        let id: String
        let title: String
        let remindAt: Date
        let isCompleted: Bool

        public init(id: String, title: String, remindAt: Date, isCompleted: Bool) {
            (self.id, self.title, self.remindAt, self.isCompleted) = (id, title, remindAt, isCompleted)
        }
    }

    /// `blockMinutes` nil turns heads-ups off; `shutdownTime` nil has no shutdown reminder.
    public struct Input: Sendable {
        let day: String
        let blocks: [Block]
        let blockMinutes: Int?
        let tasks: [TaskReminder]
        let shutdownTime: String?
        let isShutdown: Bool
        let now: Date
        let calendar: Calendar

        public init(
            day: String, blocks: [Block], blockMinutes: Int?, tasks: [TaskReminder], shutdownTime: String?,
            isShutdown: Bool, now: Date, calendar: Calendar
        ) {
            (self.day, self.blocks, self.blockMinutes, self.tasks) = (day, blocks, blockMinutes, tasks)
            (self.shutdownTime, self.isShutdown, self.now, self.calendar) = (shutdownTime, isShutdown, now, calendar)
        }
    }

    /// Only reminders still ahead of `now`, soonest first. After shutdown the
    /// day's block heads-ups and the shutdown reminder are dropped; a task's
    /// own reminder stays, because the user set it for that moment.
    public static func plan(_ input: Input) -> [PlannedReminder] {
        let dayReminders = input.isShutdown ? [] : headsUps(input) + shutdown(input)
        let all = dayReminders + taskReminders(input)
        return Array(all.filter { $0.fireDate > input.now }.sorted { $0.fireDate < $1.fireDate }.prefix(limit))
    }

    private static func headsUps(_ input: Input) -> [PlannedReminder] {
        guard let minutes = input.blockMinutes else { return [] }
        return input.blocks.compactMap { block in
            guard let start = ReminderClock.date(day: block.day, time: block.startTime, calendar: input.calendar)
            else { return nil }
            let clock = DayString.time(start, calendar: input.calendar)
            return PlannedReminder(
                id: idPrefix + "block.\(block.id)", fireDate: start - TimeInterval(minutes * 60), title: block.title,
                body: "Starts in \(minutes) min, at \(clock)")
        }
    }

    private static func taskReminders(_ input: Input) -> [PlannedReminder] {
        input.tasks.filter { !$0.isCompleted }.map { task in
            PlannedReminder(
                id: idPrefix + "task.\(task.id)", fireDate: task.remindAt, title: task.title, body: "Task reminder")
        }
    }

    private static func shutdown(_ input: Input) -> [PlannedReminder] {
        guard let time = input.shutdownTime,
            let fire = ReminderClock.date(day: input.day, time: time, calendar: input.calendar)
        else { return [] }
        return [
            PlannedReminder(
                id: idPrefix + "shutdown.\(input.day)", fireDate: fire, title: "Time to shut down",
                body: "Review the day and close it out.")
        ]
    }
}

/// A `YYYY-MM-DD` day and the server's "HH:MM" or "HH:MM:SS" wall-clock
/// time, as one instant in the user's calendar.
///
///     ReminderClock.date(day: "2026-03-07", time: "14:00:00", calendar: .current)
enum ReminderClock {
    static func date(day: String, time: String, calendar: Calendar) -> Date? {
        guard let match = time.wholeMatch(of: /(\d{2}):(\d{2})(?::(\d{2}))?/),
            let hour = Int(match.1), let minute = Int(match.2),
            let start = DayString.date(day, calendar: calendar)
        else { return nil }
        let second = match.3.flatMap { Int($0) } ?? 0
        return calendar.date(bySettingHour: hour, minute: minute, second: second, of: start)
    }
}
