import Testing

@testable import OmakaseFeatures

/// A place's open tasks grouped Overdue/Today/Upcoming/No date (spec §5),
/// given the client's today.
struct PlaceSectionsTests {
    private func card(_ id: String, day: String?) -> FocusCard {
        FocusCard(
            id: id, title: id, priority: "medium", minutes: nil, isCompleted: false, kanbanStatus: "todo",
            scheduledDay: day, dueDay: nil, isCarriedOver: false)
    }

    @Test func aPastDayIsOverdue() {
        let groups = PlaceSections.group([card("t1", day: "2026-09-20")], today: "2026-09-27")
        #expect(groups.map(\.section) == [.overdue])
    }

    @Test func todaysDayIsToday() {
        let groups = PlaceSections.group([card("t1", day: "2026-09-27")], today: "2026-09-27")
        #expect(groups.map(\.section) == [.today])
    }

    @Test func aFutureDayIsUpcoming() {
        let groups = PlaceSections.group([card("t1", day: "2026-09-28")], today: "2026-09-27")
        #expect(groups.map(\.section) == [.upcoming])
    }

    @Test func noDayIsNoDate() {
        let groups = PlaceSections.group([card("t1", day: nil)], today: "2026-09-27")
        #expect(groups.map(\.section) == [.noDate])
    }

    @Test func emptySectionsAreLeftOut() {
        let groups = PlaceSections.group([card("t1", day: "2026-09-27")], today: "2026-09-27")
        #expect(groups.count == 1)
    }

    @Test func sectionsComeInOverdueTodayUpcomingNoDateOrder() {
        let cards = [
            card("upcoming", day: "2026-09-28"), card("noDate", day: nil), card("today", day: "2026-09-27"),
            card("overdue", day: "2026-09-20"),
        ]
        let groups = PlaceSections.group(cards, today: "2026-09-27")
        #expect(groups.map(\.section) == [.overdue, .today, .upcoming, .noDate])
    }

    @Test func eachSectionKeepsTheIncomingOrder() {
        let cards = [card("newer", day: "2026-09-27"), card("older", day: "2026-09-27")]
        let groups = PlaceSections.group(cards, today: "2026-09-27")
        #expect(groups.first?.cards.map(\.id) == ["newer", "older"])
    }

    @Test func sectionTitlesReadInEnglish() {
        #expect(PlaceSection.overdue.title == "Overdue")
        #expect(PlaceSection.today.title == "Today")
        #expect(PlaceSection.upcoming.title == "Upcoming")
        #expect(PlaceSection.noDate.title == "No date")
    }
}
