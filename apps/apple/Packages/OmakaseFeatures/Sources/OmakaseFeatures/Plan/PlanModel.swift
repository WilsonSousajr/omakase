import Foundation
import Observation

/// The current moment on the grid: which column the now line is on, and where.
public struct CalendarNow: Equatable, Sendable {
    public let day: String
    public let minutes: Int

    public init(day: String, minutes: Int) { (self.day, self.minutes) = (day, minutes) }
}

/// What Plan shows (spec M4, N1): a day or a week around an anchor day,
/// moved by Today, ‹ and ›. The week starts on Monday: the profile has no
/// week-start preference to read. Its writes and range reads are injected
/// (#203), so the app wires them to the outbox and tests record them.
///
///     let plan = PlanModel(actions: services.planActions { handle($0) }) { FocusDay().today }
///     plan.mode = .week; plan.next()   // the following week
@Observable
@MainActor
public final class PlanModel {
    public enum Mode: String, CaseIterable, Sendable {
        case day
        case week
    }

    public var mode: Mode
    public private(set) var anchorDay: String
    /// A drop that overlaps a block, waiting on "Place anyway?".
    public internal(set) var pending: PlanPendingPlacement?
    /// What the detail panel shows (#217); nil hides the panel.
    public internal(set) var selection: PlanSelection?
    /// The task #218's editor sheet is open on, or nil when it is closed.
    public var editingID: String?
    public let calendar: Calendar
    private let today: () -> String
    @ObservationIgnored let actions: Actions
    /// Catch-ups refresh the range only while Plan is on screen; the window
    /// also reads this to refresh the Calendar.app overlay only while Plan
    /// shows (#256, replacing the section-equality check the app owned).
    @ObservationIgnored public private(set) var isShowing = false

    public init(
        mode: Mode = .day, calendar: Calendar = PlanModel.weekCalendar(), actions: Actions = .none,
        today: @escaping () -> String
    ) {
        (self.mode, self.calendar, self.actions, self.today) = (mode, calendar, actions, today)
        anchorDay = today()
    }

    /// `base` with weeks starting on Monday.
    public nonisolated static func weekCalendar(_ base: Calendar = .current) -> Calendar {
        var calendar = base
        calendar.firstWeekday = 2
        return calendar
    }

    /// The columns, as "YYYY-MM-DD": the anchor, or the week that holds it.
    public var visibleDays: [String] { visibleDates.map { DayString.format($0, calendar: calendar) } }

    public var title: String {
        let dates = visibleDates
        guard let first = dates.first, let last = dates.last else { return anchorDay }
        return mode == .day ? dayTitle(first) : weekTitle(first, last)
    }

    public func goToday() { anchorDay = today() }
    public func previous() { move(by: -1) }
    public func next() { move(by: 1) }

    /// `show()`/`hide()` (`PlanModel+Writes`) call this: `isShowing`'s
    /// `private(set)` only reaches this file, so they can't set it directly.
    func setShowing(_ value: Bool) { isShowing = value }

    /// A week column's header, "Mon 21".
    public func dayHeader(_ day: String) -> String { DayString.short(day, calendar: calendar) ?? day }

    public func now(at date: Date) -> CalendarNow {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return CalendarNow(
            day: DayString.format(date, calendar: calendar), minutes: (parts.hour ?? 0) * 60 + (parts.minute ?? 0))
    }

    private var visibleDates: [Date] {
        guard let anchor = DayString.date(anchorDay, calendar: calendar) else { return [] }
        guard mode == .week, let week = calendar.dateInterval(of: .weekOfYear, for: anchor) else { return [anchor] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: week.start) }
    }

    private func move(by steps: Int) {
        guard let anchor = DayString.date(anchorDay, calendar: calendar),
            let moved = calendar.date(byAdding: .day, value: steps * (mode == .week ? 7 : 1), to: anchor)
        else { return }
        anchorDay = DayString.format(moved, calendar: calendar)
    }

    /// "Sat, 26 Sep".
    private func dayTitle(_ date: Date) -> String {
        let weekday = calendar.shortWeekdaySymbols[calendar.component(.weekday, from: date) - 1]
        return "\(weekday), \(dayAndMonth(date))"
    }

    /// "21 – 27 Sep 2026", naming the first month and year only when they differ.
    private func weekTitle(_ first: Date, _ last: Date) -> String {
        let end = "\(dayAndMonth(last)) \(calendar.component(.year, from: last))"
        if calendar.component(.year, from: first) != calendar.component(.year, from: last) {
            return "\(dayAndMonth(first)) \(calendar.component(.year, from: first)) – \(end)"
        }
        if calendar.component(.month, from: first) != calendar.component(.month, from: last) {
            return "\(dayAndMonth(first)) – \(end)"
        }
        return "\(calendar.component(.day, from: first)) – \(end)"
    }

    /// "26 Sep".
    private func dayAndMonth(_ date: Date) -> String {
        let month = calendar.shortMonthSymbols[calendar.component(.month, from: date) - 1]
        return "\(calendar.component(.day, from: date)) \(month)"
    }
}
