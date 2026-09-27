import Foundation
import Observation

/// Plan's Calendar.app overlay (#229): off by default, access asked on the
/// first enable, and the visible days' events as grid items. The toggle is
/// stored through injected closures, so the app keeps it in UserDefaults.
///
///     let overlay = CalendarOverlayModel(source: calendar, isStored: { stored }, store: { stored = $0 })
///     await overlay.setEnabled(true); await overlay.refresh(days: plan.visibleDays)
@Observable
@MainActor
public final class CalendarOverlayModel {
    public static let deniedMessage = "Omakase needs access in System Settings > Privacy > Calendars"

    public private(set) var isEnabled: Bool
    /// Why enabling failed, until dismissed.
    public private(set) var message: String?
    public private(set) var items: [CalendarItem] = []
    @ObservationIgnored private let source: any ExternalCalendar
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let store: (Bool) -> Void
    /// The last days asked for, read again when the overlay is enabled.
    @ObservationIgnored private var days: [String] = []

    public init(
        source: any ExternalCalendar, calendar: Calendar = .current, isStored: () -> Bool,
        store: @escaping (Bool) -> Void
    ) {
        (self.source, self.calendar, self.store) = (source, calendar, store)
        // Access revoked in System Settings turns a stored "on" off.
        isEnabled = isStored() && source.access == .granted
    }

    /// The toggle: on asks for access first, and a denial leaves it off.
    public func setEnabled(_ isOn: Bool) async {
        guard isOn else { return disable() }
        guard await hasAccess() else {
            message = Self.deniedMessage
            return
        }
        (isEnabled, message) = (true, nil)
        store(true)
        await refresh(days: days)
    }

    public func dismissMessage() { message = nil }

    /// Reads `days`' events while the overlay is on.
    public func refresh(days: [String]) async {
        self.days = days
        guard isEnabled, let range = range(of: days) else { return }
        let events = await source.events(from: range.lowerBound, to: range.upperBound)
        // Turned off, or moved on to other days, while the read was out.
        guard isEnabled, days == self.days else { return }
        items = events.flatMap { CalendarItem.external($0, calendar: calendar) }.filter { days.contains($0.day) }
    }

    private func disable() {
        (isEnabled, items) = (false, [])
        store(false)
    }

    private func hasAccess() async -> Bool {
        source.access == .granted ? true : await source.requestAccess()
    }

    /// From the first day's midnight to the midnight after the last.
    private func range(of days: [String]) -> ClosedRange<Date>? {
        guard let first = days.first.flatMap({ DayString.date($0, calendar: calendar) }),
            let last = days.last.flatMap({ DayString.date($0, calendar: calendar) }),
            let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: last))
        else { return nil }
        return calendar.startOfDay(for: first)...end
    }
}
