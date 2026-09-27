import Foundation
import Testing

@testable import OmakaseFeatures

/// Plan's navigation (spec M4, N1): a day or a Monday-start week around an
/// anchor, moved by today, previous and next, with the header's title.
@MainActor
struct PlanModelTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return PlanModel.weekCalendar(calendar)
    }()

    func model(today: String = "2026-09-26", mode: PlanModel.Mode = .day) -> PlanModel {
        PlanModel(mode: mode, calendar: calendar) { today }
    }

    @Test func theWeekStartsOnMonday() {
        #expect(calendar.firstWeekday == 2)
    }

    @Test func itOpensOnTodaysDay() {
        let plan = model()
        #expect(plan.mode == .day)
        #expect(plan.anchorDay == "2026-09-26")
        #expect(plan.visibleDays == ["2026-09-26"])
        #expect(plan.title == "Sat, 26 Sep")
    }

    @Test func theWeekIsMondayToSundayAroundTheAnchor() {
        let plan = model(mode: .week)
        #expect(
            plan.visibleDays == [
                "2026-09-21", "2026-09-22", "2026-09-23", "2026-09-24", "2026-09-25", "2026-09-26", "2026-09-27",
            ])
        #expect(plan.title == "21 – 27 Sep 2026")
    }

    @Test func aSundayBelongsToTheWeekBeforeIt() {
        #expect(model(today: "2026-09-27", mode: .week).visibleDays.first == "2026-09-21")
    }

    @Test func nextAndPreviousMoveADayInDayMode() {
        let plan = model(today: "2026-09-30")
        plan.next()
        #expect(plan.anchorDay == "2026-10-01")
        #expect(plan.title == "Thu, 1 Oct")
        plan.previous()
        plan.previous()
        #expect(plan.anchorDay == "2026-09-29")
    }

    @Test func nextAndPreviousMoveAWeekInWeekMode() {
        let plan = model(mode: .week)
        plan.next()
        #expect(plan.visibleDays.first == "2026-09-28")
        #expect(plan.title == "28 Sep – 4 Oct 2026")
        plan.previous()
        plan.previous()
        #expect(plan.visibleDays.first == "2026-09-14")
    }

    @Test func aWeekAcrossNewYearNamesBothYears() {
        #expect(model(today: "2026-12-30", mode: .week).title == "28 Dec 2026 – 3 Jan 2027")
    }

    @Test func todayReturnsToTheCurrentDay() {
        var today = "2026-09-26"
        let plan = PlanModel(calendar: calendar) { today }
        plan.next()
        plan.next()
        today = "2026-09-27"
        plan.goToday()
        #expect(plan.anchorDay == "2026-09-27")
    }

    @Test func switchingToWeekKeepsTheAnchor() {
        let plan = model()
        plan.next()
        plan.mode = .week
        #expect(plan.anchorDay == "2026-09-27")
        #expect(plan.visibleDays.last == "2026-09-27")
    }

    @Test func aColumnIsHeadedByItsShortDay() {
        #expect(model().dayHeader("2026-09-21") == "Mon 21")
        #expect(model().dayHeader("nonsense") == "nonsense")
    }

    @Test func nowIsTheCalendarsDayAndMinute() {
        let now = model().now(at: Date(timeIntervalSince1970: 1_790_433_000))  // 2026-09-26 14:30 UTC
        #expect(now == CalendarNow(day: "2026-09-26", minutes: 870))
    }
}
