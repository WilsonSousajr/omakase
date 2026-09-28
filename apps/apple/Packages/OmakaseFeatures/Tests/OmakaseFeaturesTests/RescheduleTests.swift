import Foundation
import Testing

@testable import OmakaseFeatures

struct RescheduleTests {
    let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    @Test func todayIsTheGivenDay() {
        #expect(RescheduleOption.today.day(from: "2026-03-07", calendar: utc) == "2026-03-07")
    }

    @Test func tomorrowCrossesAMonthEnd() {
        #expect(RescheduleOption.tomorrow.day(from: "2026-02-28", calendar: utc) == "2026-03-01")
        #expect(RescheduleOption.tomorrow.day(from: "2026-12-31", calendar: utc) == "2027-01-01")
    }

    @Test func aPickedDateIsItsDayInTheCalendar() {
        let picked = Date(timeIntervalSince1970: 1_773_450_000)  // 2026-03-14 01:00 UTC
        #expect(RescheduleOption.date(picked).day(from: "2026-03-07", calendar: utc) == "2026-03-14")
    }

    @Test func backlogIsNoDay() {
        // M3.1 sends this as an explicit null (Review Focus 2).
        #expect(RescheduleOption.backlog.day(from: "2026-03-07", calendar: utc) == nil)
    }

    @Test func aMalformedTodayFallsBackToNoTomorrow() {
        #expect(RescheduleOption.tomorrow.day(from: "07-03-2026", calendar: utc) == nil)
    }
}
