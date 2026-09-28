/// The blocks a placement would overlap. Overlaps are a warning, not a
/// refusal (spec M4, Decisions): the drop asks, and the server stays
/// permissive. Computed from the local blocks, so it works offline.
///
///     PlanOverlap.titles(for: placement, among: items, excluding: moving.id)   // ["Essay"]
public enum PlanOverlap {
    /// Other blocks on the placement's day that share any minute with it, in
    /// time order; one ending as it starts only touches it.
    public static func titles(
        for placement: PlanPlacement, among items: [CalendarItem], excluding id: String? = nil
    ) -> [String] {
        items
            .filter { $0.kind == .block && $0.day == placement.day && $0.id != id }
            .filter { $0.start < placement.end && placement.start < $0.end }
            .sorted { ($0.start, $0.end) < ($1.start, $1.end) }
            .map(\.title)
    }

    /// "Overlaps Essay, Review PR. Place anyway?"
    public static func question(_ titles: [String]) -> String {
        "Overlaps \(titles.joined(separator: ", ")). Place anyway?"
    }
}
