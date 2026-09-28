import OmakaseStore
import Testing

@testable import OmakaseFeatures

/// The sidebar's places (spec §6, #260): Work's projects under their
/// workspaces, Study's disciplines under the semester, and Life, each
/// header counting what its places hold.
struct SidebarPlacesTests {
    private let omakase = PlaceEntry(parent: .project("p1"), title: "Omakase", group: nil, color: KindTint.work)
    private let lab = PlaceEntry(parent: .project("p2"), title: "Lab", group: nil, color: KindTint.work)
    private let algebra = PlaceEntry(
        parent: .discipline("d1"), title: "Linear algebra", group: nil, color: KindTint.study)

    private func row(_ entry: PlaceEntry, count: Int) -> SidebarPlaceRow {
        SidebarPlaceRow(
            place: PlaceDirectory.place(for: entry.parent), title: entry.title, color: entry.color, count: count)
    }

    private func sections(_ directory: PlaceDirectory, _ places: [TaskPlace: Int] = [:]) -> [SidebarKindSection] {
        SidebarPlaces.sections(directory, counts: SidebarCounts(places: places, inbox: 0))
    }

    @Test func oneWorkspaceListsItsProjectsWithNoSubHeader() {
        let directory = PlaceDirectory(projects: [lab, omakase], disciplines: [], semesterTitle: nil)
        let work = sections(directory, [.project("p1"): 7, .project("p2"): 2])[0]
        #expect(work.area == .work && work.selection == .item(.projects) && work.count == 9)
        #expect(work.groups == [SidebarPlaceGroup(title: nil, rows: [row(lab, count: 2), row(omakase, count: 7)])])
    }

    @Test func twoWorkspacesEachGetASubHeader() {
        let client = PlaceEntry(parent: .project("p1"), title: "Audit", group: "Client", color: KindTint.work)
        let home = PlaceEntry(parent: .project("p2"), title: "Garden", group: "Home", color: KindTint.work)
        let directory = PlaceDirectory(projects: [client, home], disciplines: [], semesterTitle: nil)
        let work = sections(directory, [.project("p2"): 3])[0]
        #expect(work.count == 3)
        #expect(
            work.groups == [
                SidebarPlaceGroup(title: "Client", rows: [row(client, count: 0)]),
                SidebarPlaceGroup(title: "Home", rows: [row(home, count: 3)]),
            ])
    }

    @Test func studyListsTheSemestersDisciplinesUnderItsTitle() {
        let directory = PlaceDirectory(projects: [], disciplines: [algebra], semesterTitle: "Fall 2026")
        let study = sections(directory, [.discipline("d1"): 4])[1]
        #expect(study.area == .study && study.selection == .item(.study) && study.count == 4)
        #expect(study.groups == [SidebarPlaceGroup(title: "Fall 2026", rows: [row(algebra, count: 4)])])
    }

    @Test func noSemesterLeavesStudyAHeaderAlone() {
        let study = sections(.empty)[1]
        #expect(study.selection == .item(.study) && study.count == 0 && study.groups.isEmpty)
    }

    @Test func lifeIsAlwaysPresentAndOpensItsOwnList() {
        let kinds = sections(.empty, [.life: 2])
        #expect(kinds.map(\.area) == [.work, .study, .life])
        #expect(kinds[2].selection == .place(.life) && kinds[2].count == 2 && kinds[2].groups.isEmpty)
    }

    @Test func aHeaderCountsOnlyThePlacesItLists() {
        // An archived project's tasks are still cached, but it is not listed.
        let directory = PlaceDirectory(projects: [omakase], disciplines: [], semesterTitle: nil)
        #expect(sections(directory, [.project("p1"): 1, .project("archived"): 5])[0].count == 1)
    }

    @Test func aSectionIsIdentifiedByItsKind() {
        #expect(sections(.empty).map(\.id) == [.work, .study, .life])
        #expect(SidebarPlaceGroup(title: nil, rows: []).id == "")
        #expect(row(omakase, count: 0).id == .project("p1"))
    }
}
