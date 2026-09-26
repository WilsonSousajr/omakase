import Foundation
import Testing

@testable import OmakaseFeatures

/// Spec §Verification (M3.6): what the Mac schedules for the day.
struct ReminderPlannerTests {
    let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()
    let now = Date(timeIntervalSince1970: 1_772_884_800)  // 2026-03-07 12:00 UTC

    func input(
        blocks: [ReminderPlanner.Block] = [], minutes: Int? = 5, tasks: [ReminderPlanner.TaskReminder] = [],
        shutdown: String? = nil, isShutdown: Bool = false
    ) -> ReminderPlanner.Input {
        ReminderPlanner.Input(
            day: "2026-03-07", blocks: blocks, blockMinutes: minutes, tasks: tasks, shutdownTime: shutdown,
            isShutdown: isShutdown, now: now, calendar: utc)
    }

    func block(_ id: String, at time: String) -> ReminderPlanner.Block {
        ReminderPlanner.Block(id: id, day: "2026-03-07", startTime: time, title: "Essay")
    }

    func task(_ id: String, in seconds: TimeInterval, done: Bool = false) -> ReminderPlanner.TaskReminder {
        ReminderPlanner.TaskReminder(id: id, title: "Call", remindAt: now + seconds, isCompleted: done)
    }

    @Test func aBlockStartingInThreeMinutesWithAFiveMinuteHeadsUpGetsNone() {
        // Its fire date, 11:58, has already passed.
        #expect(ReminderPlanner.plan(input(blocks: [block("b1", at: "12:03:00")])).isEmpty)
    }

    @Test func aBlockLaterTodayGetsAHeadsUpBeforeItStarts() {
        let plan = ReminderPlanner.plan(input(blocks: [block("b1", at: "14:00:00")]))
        #expect(plan.map(\.id) == ["omakase.reminder.block.b1"])
        #expect(plan.first?.fireDate == now + 115 * 60)
        #expect(plan.first?.title == "Essay" && plan.first?.body == "Starts in 5 min, at 14:00")
    }

    @Test func noHeadsUpWhenTheProfileTurnsThemOff() {
        #expect(ReminderPlanner.plan(input(blocks: [block("b1", at: "14:00:00")], minutes: nil)).isEmpty)
    }

    @Test func aBlockWithAnUnreadableTimeIsSkipped() {
        #expect(ReminderPlanner.plan(input(blocks: [block("b1", at: "2pm")])).isEmpty)
    }

    @Test func aTaskReminderInTheFutureIsKeptAndOneInThePastDropped() {
        let plan = ReminderPlanner.plan(input(tasks: [task("t1", in: 600), task("t2", in: -60)]))
        #expect(plan.map(\.id) == ["omakase.reminder.task.t1"])
        #expect(plan.first?.fireDate == now + 600 && plan.first?.title == "Call")
    }

    @Test func aCompletedTaskIsNotReminded() {
        #expect(ReminderPlanner.plan(input(tasks: [task("t1", in: 600, done: true)])).isEmpty)
    }

    @Test func theShutdownTimeIsReminded() {
        let plan = ReminderPlanner.plan(input(shutdown: "17:30:00"))
        #expect(plan.map(\.id) == ["omakase.reminder.shutdown.2026-03-07"])
        #expect(plan.first?.fireDate == now + 330 * 60 && plan.first?.title == "Time to shut down")
    }

    @Test func aShutdownTimeAlreadyPastIsNotReminded() {
        #expect(ReminderPlanner.plan(input(shutdown: "09:00:00")).isEmpty)
    }

    @Test func afterShutdownOnlyTaskRemindersStay() {
        let plan = ReminderPlanner.plan(
            input(blocks: [block("b1", at: "14:00:00")], tasks: [task("t1", in: 600)], shutdown: "17:30",
                isShutdown: true))
        #expect(plan.map(\.id) == ["omakase.reminder.task.t1"])
    }

    @Test func remindersAreSortedByFireDate() {
        let plan = ReminderPlanner.plan(
            input(blocks: [block("b1", at: "14:00:00")], tasks: [task("t1", in: 9000), task("t2", in: 60)]))
        #expect(plan.map(\.id) == ["omakase.reminder.task.t2", "omakase.reminder.block.b1", "omakase.reminder.task.t1"])
    }

    @Test func moreThanSixtyFourKeepsTheSoonestSixtyFour() {
        // 64 is the system's pending-notification limit.
        let tasks = (1...70).reversed().map { task("t\($0)", in: TimeInterval($0 * 60)) }
        let plan = ReminderPlanner.plan(input(tasks: tasks))
        #expect(plan.count == 64 && plan.first?.id == "omakase.reminder.task.t1")
        #expect(plan.last?.id == "omakase.reminder.task.t64")
    }

    @Test func everyIDCarriesThePrefix() {
        let plan = ReminderPlanner.plan(
            input(blocks: [block("b1", at: "14:00:00")], tasks: [task("t1", in: 60)], shutdown: "17:30:00"))
        #expect(plan.count == 3 && plan.allSatisfy { $0.id.hasPrefix(ReminderPlanner.idPrefix) })
    }
}
