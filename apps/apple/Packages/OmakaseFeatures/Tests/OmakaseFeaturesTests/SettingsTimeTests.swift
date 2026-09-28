import Foundation
import Testing

@testable import OmakaseFeatures

/// The shutdown reminder's time as the picker shows it and the server keeps it (#228).
struct SettingsTimeTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        return calendar
    }

    @Test func aPickedTimeIsTheServersWallClockString() throws {
        let parts = DateComponents(year: 2026, month: 9, day: 27, hour: 21, minute: 30)
        let date = try #require(calendar.date(from: parts))
        #expect(ReminderClock.time(from: date, calendar: calendar) == "21:30:00")
    }

    @Test func theStringRoundTripsThroughThePicker() throws {
        let date = try #require(ReminderClock.date(day: "2026-09-27", time: "07:05:00", calendar: calendar))
        #expect(ReminderClock.time(from: date, calendar: calendar) == "07:05:00")
    }
}

/// Settings shows who is signed in (#228), read online when it opens.
@MainActor
struct SettingsAccountTests {
    @Test func theAccountsEmailIsLoaded() async {
        let settings = SettingsModel(
            actions: .init(
                save: { _ in }, loginItemEnabled: { false }, setLoginItem: { _ in },
                account: { "ada@example.com" }),
            schedule: { _ in })
        await settings.loadAccount()
        #expect(settings.email == "ada@example.com")
    }
}
