import Foundation
import Testing

@testable import OmakaseFeatures

/// The "Remind me" menu's choices (M3.6 spec §2).
struct ReminderChoiceTests {
    let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()
    let noon = Date(timeIntervalSince1970: 1_772_884_800)  // 2026-03-07 12:00 UTC

    @Test func inAnHourIsAnHourFromNow() {
        #expect(ReminderChoice.inAnHour.date(from: noon, calendar: utc) == noon + 3600)
    }

    @Test func thisEveningIsSixToday() {
        #expect(ReminderChoice.thisEvening.date(from: noon, calendar: utc) == noon + 6 * 3600)
    }

    @Test func tomorrowMorningIsNineTomorrow() {
        #expect(ReminderChoice.tomorrowMorning.date(from: noon, calendar: utc) == noon + 21 * 3600)
    }

    @Test func aPickedTimeIsItselfAndClearIsNone() {
        #expect(ReminderChoice.at(noon + 42).date(from: noon, calendar: utc) == noon + 42)
        #expect(ReminderChoice.clear.date(from: noon, calendar: utc) == nil)
    }

    @Test func thisEveningIsOfferedBeforeSix() {
        #expect(ReminderChoice.presets(now: noon, calendar: utc) == [.inAnHour, .thisEvening, .tomorrowMorning])
    }

    @Test func thisEveningIsHiddenOnceItHasPassed() {
        let evening = noon + 6 * 3600
        #expect(ReminderChoice.presets(now: evening, calendar: utc) == [.inAnHour, .tomorrowMorning])
    }

    @Test func eachPresetHasItsMenuTitle() {
        let titles = [ReminderChoice.inAnHour, .thisEvening, .tomorrowMorning, .at(noon), .clear].map(\.title)
        #expect(titles == ["In 1 hour", "This evening (18:00)", "Tomorrow morning (09:00)", "Pick a time…", "Clear"])
    }
}
