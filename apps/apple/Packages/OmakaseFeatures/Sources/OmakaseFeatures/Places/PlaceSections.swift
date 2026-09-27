import Foundation

/// One of the four buckets a place's list divides its open tasks into (spec §5).
public enum PlaceSection: String, CaseIterable, Sendable {
    case overdue
    case today
    case upcoming
    case noDate

    public var title: String {
        switch self {
        case .overdue: "Overdue"
        case .today: "Today"
        case .upcoming: "Upcoming"
        case .noDate: "No date"
        }
    }
}

/// One section's run of cards, in the order `PlaceSections.group` built it.
public struct PlaceTaskGroup: Identifiable, Equatable, Sendable {
    public let section: PlaceSection
    public let cards: [FocusCard]

    public var id: PlaceSection { section }

    public init(section: PlaceSection, cards: [FocusCard]) {
        (self.section, self.cards) = (section, cards)
    }
}

/// Pure grouping of a place's open tasks (spec §5): Overdue, Today, Upcoming
/// or No date, given the client's today. `cards` is assumed already sorted
/// as the Inbox sorts (newest updated first, `TaskRecord.updatedAt` reverse);
/// grouping only partitions that order into runs, it never re-sorts.
///
///     PlaceSections.group(cards, today: "2026-09-27")   // one run per non-empty section
public enum PlaceSections {
    /// One run per non-empty section, in `PlaceSection.allCases` order.
    public static func group(_ cards: [FocusCard], today: String) -> [PlaceTaskGroup] {
        var buckets: [PlaceSection: [FocusCard]] = [:]
        for card in cards { buckets[section(for: card, today: today), default: []].append(card) }
        return PlaceSection.allCases.compactMap { section in
            buckets[section].map { PlaceTaskGroup(section: section, cards: $0) }
        }
    }

    private static func section(for card: FocusCard, today: String) -> PlaceSection {
        guard let day = card.scheduledDay else { return .noDate }
        if day < today { return .overdue }
        return day == today ? .today : .upcoming
    }
}
