import Foundation

/// The small labels beside a task, in reading order: where it was carried
/// from, when it is due (#129), and its estimate.
///
///     FocusMarks.labels(for: card, day: "2026-03-07", calendar: .current)   // ["from Mon 2", "Due Fri 13", "45m"]
enum FocusMarks {
    static func labels(for card: FocusCard, day: String, calendar: Calendar) -> [String] {
        [
            card.carriedFromLabel(calendar: calendar),
            card.dueLabel(today: day, calendar: calendar),
            card.minutes.map { "\($0)m" },
        ]
        .compactMap { $0 }
    }
}
