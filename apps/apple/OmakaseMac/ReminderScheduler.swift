import Foundation
import OmakaseFeatures
import OmakaseStore
import SwiftData
import UserNotifications

/// Hands the day's reminder plan to UserNotifications (M3.6 spec §2). It
/// reads the store, asks the pure ReminderPlanner, and replaces the pending
/// `omakase.reminder.*` requests with the plan: a stable id re-added
/// replaces its request, and one no longer planned is removed. The timer's
/// phase-end request (PhaseNotifier) has another id and is never touched.
///
///     scheduler.replan(from: container.mainContext)   // after each refresh and write
@MainActor
final class ReminderScheduler {
    private let center = UNUserNotificationCenter.current()
    /// The last replacement: each waits for the one before, so two quick
    /// replans can't interleave their removes and adds.
    private var replacing: Task<Void, Never>?

    func replan(from context: ModelContext, day: String = FocusDay().today, now: Date = .now) {
        let plan = ReminderPlanner.plan(Self.input(context, day: day, now: now))
        let (previous, center) = (replacing, center)
        replacing = Task {
            await previous?.value
            await Self.replace(with: plan, in: center)
        }
    }

    private static func replace(with plan: [PlannedReminder], in center: UNUserNotificationCenter) async {
        let planned = Set(plan.map(\.id))
        let stale = await center.pendingNotificationRequests().map(\.identifier)
            .filter { $0.hasPrefix(ReminderPlanner.idPrefix) && !planned.contains($0) }
        center.removePendingNotificationRequests(withIdentifiers: stale)
        // The same authorization the timer's notifications ask for (M3.3); asked once.
        guard !plan.isEmpty, (try? await center.requestAuthorization(options: [.alert, .sound])) == true else {
            return
        }
        for reminder in plan { try? await center.add(request(for: reminder)) }
    }

    private static func request(for reminder: PlannedReminder) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        (content.title, content.body, content.sound) = (reminder.title, reminder.body, .default)
        let parts = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: reminder.fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        return UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger)
    }

    private static func input(_ context: ModelContext, day: String, now: Date) -> ReminderPlanner.Input {
        let profile = try? context.fetch(FetchDescriptor<ProfileRecord>()).first
        let review = try? context.fetch(FetchDescriptor<DailyReviewRecord>(predicate: #Predicate { $0.day == day }))
            .first
        let tasks = (try? context.fetch(FetchDescriptor<TaskRecord>())) ?? []
        let reminders = tasks.compactMap { task in
            task.remindAt.map { date in
                ReminderPlanner.TaskReminder(
                    id: task.id, title: task.title, remindAt: date, isCompleted: task.isCompleted)
            }
        }
        return ReminderPlanner.Input(
            day: day, blocks: blocks(context, day: day, tasks: tasks), blockMinutes: profile?.blockReminderMinutes,
            tasks: reminders, shutdownTime: profile?.shutdownReminderTime, isShutdown: review?.isShutdown ?? false,
            now: now, calendar: .current)
    }

    /// The day's blocks, titled by their task or study block when the store has it.
    private static func blocks(
        _ context: ModelContext, day: String, tasks: [TaskRecord]
    ) -> [ReminderPlanner.Block] {
        let onDay = FetchDescriptor<TimeBlockRecord>(predicate: #Predicate { $0.day == day })
        let found = (try? context.fetch(onDay)) ?? []
        let studies = (try? context.fetch(FetchDescriptor<StudyBlockRecord>())) ?? []
        let titles = Dictionary(
            tasks.map { ($0.id, $0.title) } + studies.map { ($0.id, $0.title) },
            uniquingKeysWith: { first, _ in first })
        return found.map { block in
            let title = (block.taskID ?? block.studyBlockID).flatMap { titles[$0] } ?? "Time block"
            return ReminderPlanner.Block(id: block.id, day: block.day, startTime: block.startTime, title: title)
        }
    }
}
