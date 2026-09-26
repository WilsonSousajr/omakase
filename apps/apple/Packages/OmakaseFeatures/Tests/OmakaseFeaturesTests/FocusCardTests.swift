import Foundation
import Testing

@testable import OmakaseFeatures

struct FocusCardTests {
    let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }()

    func card(scheduled: String? = "2026-03-07", due: String? = nil, carried: Bool = false) -> FocusCard {
        FocusCard(
            id: "t1", title: "T", priority: "medium", minutes: nil, isCompleted: false, kanbanStatus: "todo",
            scheduledDay: scheduled, dueDay: due, isCarriedOver: carried)
    }

    @Test func aCarriedCardSaysWhichDayItCameFrom() {
        #expect(card(scheduled: "2026-03-02", carried: true).carriedFromLabel(calendar: utc) == "from Mon 2")
    }

    @Test func aCardScheduledTodayHasNoCarriedLabel() {
        #expect(card().carriedFromLabel(calendar: utc) == nil)
    }

    @Test func theDueDayShowsWhenItDiffersFromThePlanDay() {
        #expect(card(due: "2026-03-13").dueLabel(today: "2026-03-07", calendar: utc) == "Due Fri 13")
    }

    @Test func theDueDayIsHiddenWhenItIsThePlanDay() {
        #expect(card(due: "2026-03-07").dueLabel(today: "2026-03-07", calendar: utc) == nil)
        #expect(card(due: nil).dueLabel(today: "2026-03-07", calendar: utc) == nil)
    }

    @Test func aPastDueDayIsOverdue() {
        #expect(card(scheduled: "2026-03-07", due: "2026-03-05").dueLabel(today: "2026-03-07", calendar: utc) == "Overdue")
    }
}
