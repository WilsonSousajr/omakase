import Foundation
import Testing

@testable import OmakaseFeatures

final class Clock: @unchecked Sendable {
    var now: Date
    init(_ now: Date) { self.now = now }
}

struct FocusDayTests {
    let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    @Test func todayIsTheCalendarsDay() {
        let clock = Clock(Date(timeIntervalSince1970: 1_772_884_800))  // 2026-03-07 12:00 UTC
        #expect(FocusDay(clock: { clock.now }, calendar: utc).today == "2026-03-07")
    }

    @Test func theDayMovesPastMidnight() {
        // M1's known limitation: the window kept its day until relaunch.
        let clock = Clock(Date(timeIntervalSince1970: 1_772_927_999))  // 2026-03-07 23:59:59 UTC
        let day = FocusDay(clock: { clock.now }, calendar: utc)
        #expect(day.today == "2026-03-07")
        clock.now = clock.now.addingTimeInterval(2)
        #expect(day.today == "2026-03-08")
    }

    @Test func theDayIsTheUsersNotUTC() {
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let clock = Clock(Date(timeIntervalSince1970: 1_772_917_200))  // 2026-03-07 21:00 UTC
        #expect(FocusDay(clock: { clock.now }, calendar: tokyo).today == "2026-03-08")
    }
}
