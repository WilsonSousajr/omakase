import Foundation
import Testing

@testable import OmakaseFeatures

/// A calendar that answers from memory: the access it grants on request,
/// the events it holds, and the ranges it was asked for.
@MainActor
final class FakeExternalCalendar: ExternalCalendar {
    var access: ExternalCalendarAccess
    let grants: Bool
    let upcoming: [ExternalEvent]
    private(set) var requests = 0
    private(set) var ranges: [ClosedRange<Date>] = []

    init(access: ExternalCalendarAccess = .notDetermined, grants: Bool = true, upcoming: [ExternalEvent] = []) {
        (self.access, self.grants, self.upcoming) = (access, grants, upcoming)
    }

    func requestAccess() async -> Bool {
        requests += 1
        access = grants ? .granted : .denied
        return grants
    }

    func events(from start: Date, to end: Date) async -> [ExternalEvent] {
        ranges.append(start...end)
        return upcoming
    }
}

/// The overlay toggle's stored value, as UserDefaults would hold it.
@MainActor
final class FakeOverlaySetting {
    var isOn: Bool

    init(isOn: Bool = false) { self.isOn = isOn }
}

/// Plan's Calendar.app overlay (#229): off by default, access asked on the
/// first enable, a denial leaves it off with a way to fix it, and the
/// visible days' events are its items.
@MainActor
struct CalendarOverlayModelTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    func date(_ text: String) -> Date {
        ISO8601DateFormatter().date(from: text)!
    }

    func meeting(_ id: String, start: String, end: String) -> ExternalEvent {
        ExternalEvent(id: id, title: id, start: date(start), end: date(end), isAllDay: false, calendarColor: nil)
    }

    func overlay(_ source: FakeExternalCalendar, _ setting: FakeOverlaySetting) -> CalendarOverlayModel {
        CalendarOverlayModel(
            source: source, calendar: calendar, isStored: { setting.isOn }, store: { setting.isOn = $0 })
    }

    @Test func itIsOffByDefaultAndReadsNothing() async {
        let source = FakeExternalCalendar(access: .granted)
        let model = overlay(source, FakeOverlaySetting())
        await model.refresh(days: ["2026-09-28"])
        #expect(!model.isEnabled)
        #expect(model.items.isEmpty)
        #expect(source.ranges.isEmpty)
    }

    @Test func aStoredOnStaysOnWhileAccessIsGranted() {
        let model = overlay(FakeExternalCalendar(access: .granted), FakeOverlaySetting(isOn: true))
        #expect(model.isEnabled)
    }

    @Test func aStoredOnIsOffOnceAccessWasRevoked() {
        let model = overlay(FakeExternalCalendar(access: .denied), FakeOverlaySetting(isOn: true))
        #expect(!model.isEnabled)
    }

    @Test func enablingAsksForAccessFirstThenReadsTheVisibleDays() async {
        let source = FakeExternalCalendar(upcoming: [
            meeting("m", start: "2026-09-28T09:00:00Z", end: "2026-09-28T10:00:00Z")
        ])
        let setting = FakeOverlaySetting()
        let model = overlay(source, setting)
        await model.refresh(days: ["2026-09-28"])
        await model.setEnabled(true)
        #expect(source.requests == 1)
        #expect(model.isEnabled)
        #expect(setting.isOn)
        #expect(model.message == nil)
        #expect(model.items.map(\.id) == ["m@2026-09-28"])
    }

    @Test func enablingWithAccessAlreadyGrantedDoesNotAskAgain() async {
        let source = FakeExternalCalendar(access: .granted)
        let model = overlay(source, FakeOverlaySetting())
        await model.setEnabled(true)
        #expect(source.requests == 0)
        #expect(model.isEnabled)
    }

    @Test func aDenialLeavesItOffWithWhereToFixIt() async {
        let source = FakeExternalCalendar(grants: false)
        let setting = FakeOverlaySetting()
        let model = overlay(source, setting)
        await model.setEnabled(true)
        #expect(!model.isEnabled)
        #expect(!setting.isOn)
        #expect(model.message == "Omakase needs access in System Settings > Privacy > Calendars")
        model.dismissMessage()
        #expect(model.message == nil)
    }

    @Test func disablingClearsTheEventsAndIsStored() async {
        let source = FakeExternalCalendar(
            access: .granted, upcoming: [meeting("m", start: "2026-09-28T09:00:00Z", end: "2026-09-28T10:00:00Z")])
        let setting = FakeOverlaySetting(isOn: true)
        let model = overlay(source, setting)
        await model.refresh(days: ["2026-09-28"])
        await model.setEnabled(false)
        #expect(!model.isEnabled)
        #expect(!setting.isOn)
        #expect(model.items.isEmpty)
    }

    @Test func theVisibleDaysAreReadFromTheFirstMidnightToTheDayAfterTheLast() async {
        let source = FakeExternalCalendar(access: .granted)
        let model = overlay(source, FakeOverlaySetting(isOn: true))
        await model.refresh(days: ["2026-09-28", "2026-09-29"])
        #expect(source.ranges == [date("2026-09-28T00:00:00Z")...date("2026-09-30T00:00:00Z")])
    }

    @Test func onlyTheVisibleDaysPartsOfAnEventAreItems() async {
        let late = meeting("late", start: "2026-09-28T22:00:00Z", end: "2026-09-29T02:00:00Z")
        let model = overlay(FakeExternalCalendar(access: .granted, upcoming: [late]), FakeOverlaySetting(isOn: true))
        await model.refresh(days: ["2026-09-28"])
        #expect(model.items.map(\.day) == ["2026-09-28"])
    }

    @Test func noVisibleDaysReadsNothing() async {
        let source = FakeExternalCalendar(access: .granted)
        let model = overlay(source, FakeOverlaySetting(isOn: true))
        await model.refresh(days: [])
        #expect(source.ranges.isEmpty)
    }
}
