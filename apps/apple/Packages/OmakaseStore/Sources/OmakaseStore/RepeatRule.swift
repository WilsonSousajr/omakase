import Foundation

/// A series' rule as the Repeat menu sets it (#206), sent whole to
/// `PUT tasks/<id>/recurrence/`. `weekdays` are 0 (Monday) to 6, for a weekly
/// rule only; empty means the weekday of `startsOn`. Days are "YYYY-MM-DD".
///
///     RepeatRule(freq: .weekly, weekdays: [0, 2], startsOn: "2026-03-02")   // Mondays and Wednesdays
public struct RepeatRule: Equatable, Sendable, Encodable {
    public enum Frequency: String, Sendable, Encodable {
        case daily
        case weekly
        case monthly
    }

    public let freq: Frequency
    public let interval: Int
    public let weekdays: [Int]
    public let startsOn: String
    public let until: String?

    public init(freq: Frequency, interval: Int = 1, weekdays: [Int] = [], startsOn: String, until: String? = nil) {
        (self.freq, self.interval, self.weekdays, self.startsOn, self.until) = (
            freq, interval, weekdays, startsOn, until
        )
    }

    private enum CodingKeys: String, CodingKey {
        case freq, interval, weekdays, startsOn, until
    }

    /// `until` goes out as an explicit null: the PUT replaces the rule whole.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(freq, forKey: .freq)
        try container.encode(interval, forKey: .interval)
        try container.encode(weekdays, forKey: .weekdays)
        try container.encode(startsOn, forKey: .startsOn)
        try container.encode(until, forKey: .until)
    }
}
