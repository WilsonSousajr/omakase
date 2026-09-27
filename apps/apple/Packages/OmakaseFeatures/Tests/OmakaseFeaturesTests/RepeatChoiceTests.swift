import Foundation
import OmakaseStore
import Testing

@testable import OmakaseFeatures

/// The Focus panel's Repeat menu (#206): each choice is a rule counted from
/// the task's day, and Stop repeating ends the series.
struct RepeatChoiceTests {
    let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }()

    @Test func aWednesdayOffersItsWeekdayAndDayOfMonth() {
        let choices = RepeatChoice.choices(for: "2026-03-04", isRepeating: false, calendar: utc)
        #expect(choices == [.daily, .weekdays, .weekly(weekday: 2), .monthly(day: 4)])
        #expect(
            choices.map { $0.title(calendar: utc) } == [
                "Daily", "Weekdays (Mon–Fri)", "Weekly on Wednesday", "Monthly on day 4",
            ])
    }

    @Test func aRepeatingTaskCanStop() {
        let choices = RepeatChoice.choices(for: "2026-03-08", isRepeating: true, calendar: utc)
        #expect(choices.last == .stop && choices.contains(.weekly(weekday: 6)))
        #expect(RepeatChoice.stop.title(calendar: utc) == "Stop repeating")
    }

    @Test func aDayThatIsNotADayOffersOnlyTheDaylessChoices() {
        #expect(RepeatChoice.choices(for: "04/03/2026", isRepeating: false, calendar: utc) == [.daily, .weekdays])
    }

    @Test(arguments: [
        (RepeatChoice.daily, RepeatRule(freq: .daily, startsOn: "2026-03-04")),
        (.weekdays, RepeatRule(freq: .weekly, weekdays: [0, 1, 2, 3, 4], startsOn: "2026-03-04")),
        (.weekly(weekday: 2), RepeatRule(freq: .weekly, weekdays: [2], startsOn: "2026-03-04")),
        (.monthly(day: 4), RepeatRule(freq: .monthly, startsOn: "2026-03-04")),
    ])
    func eachChoiceIsARuleFromTheTasksDay(choice: RepeatChoice, rule: RepeatRule) {
        #expect(choice.rule(startsOn: "2026-03-04") == rule)
    }

    @Test func stopIsNoRule() {
        #expect(RepeatChoice.stop.rule(startsOn: "2026-03-04") == nil)
    }
}
