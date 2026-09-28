import OmakaseStore
import Testing

@testable import OmakaseFeatures

/// The counts beside each place and the Inbox (spec §6): one query of open
/// tasks, tallied the way each place's list and the Inbox filter them.
struct SidebarCountsTests {
    private func task(
        area: TaskArea = .work, project: String? = nil, discipline: String? = nil, day: String? = "2026-09-27",
        virtual: Bool = false
    ) -> SidebarOpenTask {
        SidebarOpenTask(
            area: area.rawValue, projectID: project, disciplineID: discipline, scheduledDay: day, isVirtual: virtual)
    }

    @Test func eachTaskCountsTowardItsPlace() {
        let counts = SidebarCounts.tally([
            task(project: "p1"), task(project: "p1"), task(area: .study, discipline: "d1"), task(area: .life),
        ])
        #expect(counts.count(for: .project("p1")) == 2)
        #expect(counts.count(for: .discipline("d1")) == 1)
        #expect(counts.count(for: .life) == 1)
        #expect(counts.count(for: .project("p9")) == 0)
    }

    @Test func aVirtualOccurrenceIsTheCalendarsNotAPlaces() {
        #expect(SidebarCounts.tally([task(project: "p1", virtual: true)]).count(for: .project("p1")) == 0)
    }

    @Test func workWithNoProjectCountsNowhereButTheInbox() {
        let counts = SidebarCounts.tally([task(day: nil)])
        #expect(counts.places.isEmpty && counts.inbox == 1)
    }

    @Test func theInboxCountsEveryOpenTaskWithNoDay() {
        let counts = SidebarCounts.tally([task(day: nil), task(area: .life, day: nil), task(project: "p1")])
        #expect(counts.inbox == 2)
    }

    /// The tally is a third copy of "an open task in this place", beside
    /// `TaskPlace.openTasksPredicate`, which `PlaceTasksView` and `PlaceSync`
    /// share so the two can't drift. This pins the tally to that predicate
    /// over every kind of record the two could disagree on.
    @MainActor
    @Test func theTallyAgreesWithEachPlacesPredicate() throws {
        let records = Self.fixtureRecords()
        // SidebarView's query: the tally only ever sees open tasks.
        let counts = SidebarCounts.tally(records.filter { !$0.isCompleted }.map(SidebarOpenTask.init))
        let places: [TaskPlace] = [.project("p1"), .project("p2"), .discipline("d1"), .discipline("d2"), .life]
        for place in places {
            let listed = try records.filter { try place.openTasksPredicate.evaluate($0) }.count
            #expect(counts.count(for: place) == listed, "\(place)")
        }
    }

    /// Open, completed and virtual records in a project, a discipline and
    /// Life, and a server row that says Life but names a project.
    @MainActor
    private static func fixtureRecords() -> [TaskRecord] {
        let project = TaskFiling(area: .work, parent: .project("p1"))
        let discipline = TaskFiling(area: .study, parent: .discipline("d1"))
        let life = TaskFiling(area: .life, parent: nil)
        let virtual = TaskRecord(id: "occ-1", title: "Standup", scheduledDay: "2026-09-28", filing: project)
        virtual.isVirtual = true
        let virtualLife = TaskRecord(id: "occ-2", title: "Run", scheduledDay: "2026-09-28", filing: life)
        virtualLife.isVirtual = true
        let inconsistent = TaskRecord(id: "t9", title: "Odd", filing: TaskFiling(area: .work, parent: .project("p2")))
        inconsistent.area = TaskArea.life.rawValue
        return [
            TaskRecord(id: "t1", title: "Ship", scheduledDay: "2026-09-27", filing: project),
            TaskRecord(id: "t2", title: "Plan", filing: project),
            TaskRecord(id: "t3", title: "Done", isCompleted: true, filing: project), virtual,
            TaskRecord(id: "t4", title: "Proof", filing: discipline),
            TaskRecord(id: "t5", title: "Read", isCompleted: true, filing: discipline),
            TaskRecord(id: "t6", title: "Groceries", filing: life),
            TaskRecord(id: "t7", title: "Dentist", isCompleted: true, filing: life), virtualLife, inconsistent,
        ]
    }

    @MainActor
    @Test func aRecordReadsAsPlainValues() {
        let record = TaskRecord(
            id: "t1", title: "Proof", scheduledDay: nil, filing: TaskFiling(area: .study, parent: .discipline("d1")))
        #expect(
            SidebarOpenTask(record)
                == SidebarOpenTask(
                    area: "study", projectID: nil, disciplineID: "d1", scheduledDay: nil, isVirtual: false))
    }
}
