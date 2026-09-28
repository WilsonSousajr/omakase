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

    /// The sidebar's footer reads the address each time it appears (#260),
    /// and offline the read gives nil: a known address must not turn back
    /// into "Account".
    @Test func anOfflineReadKeepsTheLastKnownAddressIssue260() async {
        let replies = AccountReplies(["ada@example.com", nil])
        let settings = SettingsModel(
            actions: .init(
                save: { _ in }, loginItemEnabled: { false }, setLoginItem: { _ in },
                account: { replies.next() }),
            schedule: { _ in })
        await settings.loadAccount()
        await settings.loadAccount()
        #expect(settings.email == "ada@example.com")
    }
}

/// A named fake for `/me`: the addresses it answers with, in order; nil is an offline read.
@MainActor
final class AccountReplies {
    private var replies: [String?]

    init(_ replies: [String?]) { self.replies = replies }

    func next() -> String? { replies.isEmpty ? nil : replies.removeFirst() }
}
