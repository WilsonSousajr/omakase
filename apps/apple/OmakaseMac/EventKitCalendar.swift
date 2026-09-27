import AppKit
import EventKit
import OmakaseFeatures

/// Calendar.app through EventKit, read-only (#229). The only place the app
/// touches EventKit: Plan sees `ExternalCalendar` and `ExternalEvent`.
/// Reading events needs full access; nothing is ever written back.
@MainActor
final class EventKitCalendar: ExternalCalendar {
    private let store = EKEventStore()

    var access: ExternalCalendarAccess {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    /// The completion form, so the non-Sendable store isn't sent across
    /// actors by an async call. The handler is `@Sendable` so it isn't
    /// inferred main-actor-isolated: EventKit calls it off the main thread.
    func requestAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            store.requestFullAccessToEvents { @Sendable granted, _ in continuation.resume(returning: granted) }
        }
    }

    func events(from start: Date, to end: Date) async -> [ExternalEvent] {
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate).map(Self.external)
    }

    /// A recurring event's occurrences share an identifier, so its start
    /// makes each one unique.
    private static func external(_ event: EKEvent) -> ExternalEvent {
        let identifier = event.eventIdentifier ?? event.calendarItemIdentifier
        return ExternalEvent(
            id: "\(identifier)-\(Int(event.startDate.timeIntervalSince1970))", title: event.title ?? "Event",
            start: event.startDate, end: event.endDate, isAllDay: event.isAllDay,
            calendarColor: event.calendar.flatMap { hex($0.cgColor) })
    }

    /// "#RRGGBB" in sRGB; nil when the colour can't be converted.
    private static func hex(_ color: CGColor?) -> String? {
        guard let color, let rgb = NSColor(cgColor: color)?.usingColorSpace(.sRGB) else { return nil }
        let channels = [rgb.redComponent, rgb.greenComponent, rgb.blueComponent].map { Int(($0 * 255).rounded()) }
        return String(format: "#%02X%02X%02X", channels[0], channels[1], channels[2])
    }
}
