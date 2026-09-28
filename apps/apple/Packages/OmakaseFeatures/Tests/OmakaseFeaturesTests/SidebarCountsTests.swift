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
