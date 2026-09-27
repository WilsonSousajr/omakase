import Foundation
import OmakaseAPI

/// The local id of a series' computed occurrence, which has no server id
/// until it is materialized (#206): stable per series and date, so a refresh
/// finds the same record and a queued write can name it.
///
///     OccurrenceID.make(series: "3859D72D-…", day: "2026-03-07")   // "occ-3859D72D-…-2026-03-07"
public enum OccurrenceID {
    public static let prefix = "occ-"

    public static func make(series: String, day: String) -> String { "\(prefix)\(series)-\(day)" }
}

extension TaskDTO {
    /// The record's key: the server's id, or the occurrence's local id when it has none.
    public var recordID: String {
        id?.uuidString ?? OccurrenceID.make(series: series?.uuidString ?? "", day: occurrenceDate?.string ?? "")
    }
}
