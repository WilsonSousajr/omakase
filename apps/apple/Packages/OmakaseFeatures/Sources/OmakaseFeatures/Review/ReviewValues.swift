import OmakaseStore

/// The review's fields as the screen edits them: every one optional, so a
/// review half done is still a review (M3.4 spec, Decisions).
///
///     ReviewValues(rating: 4, energy: 2, win: "Shipped it", isShutdown: false)
public struct ReviewValues: Equatable, Sendable {
    /// 1-5, the day's productivity rating.
    public var rating: Int?
    /// 1-3 (#130): see `ReviewEnergy`.
    public var energy: Int?
    public var win: String
    /// Only Shut down sets it (#179); an edit carries it through unchanged.
    public var isShutdown: Bool

    public static let empty = ReviewValues(rating: nil, energy: nil, win: "", isShutdown: false)

    public init(rating: Int?, energy: Int?, win: String, isShutdown: Bool) {
        (self.rating, self.energy, self.win, self.isShutdown) = (rating, energy, win, isShutdown)
    }

    /// The store's review for the day, or an empty one when there is none yet.
    @MainActor
    public init(record: DailyReviewRecord?) {
        guard let record else {
            self = .empty
            return
        }
        self.init(rating: record.rating, energy: record.energy, win: record.win, isShutdown: record.isShutdown)
    }
}

/// How much energy the day left (#130), on the server's 1-3 scale.
///
///     ReviewEnergy.steady.title   // "Steady"
public enum ReviewEnergy: Int, CaseIterable, Identifiable, Sendable {
    case low = 1
    case steady
    case high

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .low: "Low"
        case .steady: "Steady"
        case .high: "High"
        }
    }
}
