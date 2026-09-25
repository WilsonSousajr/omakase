import Foundation

/// A calendar day on the wire, exactly `YYYY-MM-DD`, in the user's calendar.
///
/// The Swift twin of the backend's `parse_client_date` (#69): "today" is the
/// client's day, never the server's (AGENTS.md invariant 2).
///
///     let today = APIDay.today()          // "2026-03-07"
public struct APIDay: Sendable, Hashable, Codable, Comparable {
    public let year: Int
    public let month: Int
    public let day: Int

    public var string: String { String(format: "%04d-%02d-%02d", year, month, day) }

    public init(date: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        (year, month, day) = (parts.year!, parts.month!, parts.day!)
    }

    public init?(string: String) {
        let pieces = string.split(separator: "-", omittingEmptySubsequences: false)
        guard pieces.count == 3, pieces.map(\.count) == [4, 2, 2],
            let year = Int(pieces[0]), let month = Int(pieces[1]), let day = Int(pieces[2]),
            APIDay.exists(year: year, month: month, day: day)
        else { return nil }
        (self.year, self.month, self.day) = (year, month, day)
    }

    public static func today(calendar: Calendar = .current, now: Date = .now) -> APIDay {
        APIDay(date: now, calendar: calendar)
    }

    public static func < (lhs: APIDay, rhs: APIDay) -> Bool { lhs.string < rhs.string }

    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let parsed = APIDay(string: raw) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "\(raw.debugDescription) is not YYYY-MM-DD"))
        }
        self = parsed
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(string)
    }

    private static func exists(year: Int, month: Int, day: Int) -> Bool {
        let calendar = Calendar(identifier: .gregorian)
        let parts = DateComponents(year: year, month: month, day: day)
        guard let date = calendar.date(from: parts) else { return false }
        return calendar.dateComponents([.year, .month, .day], from: date) == parts
    }
}
