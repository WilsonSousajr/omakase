import Foundation
import OmakaseAPI
import OmakaseStore
import SwiftData
import Testing

@testable import OmakaseFeatures

private func decode<T: Decodable>(_ json: String) throws -> T {
    try OmakaseJSON.decoder.decode(T.self, from: Data(json.utf8))
}

private func sampleWorkspace(id: String, name: String) throws -> WorkspaceDTO {
    try decode(##"{"id":"\##(id)","name":"\##(name)","color":"#a3a3a3","project_count":1}"##)
}

private func sampleProject(id: String, workspace: String, name: String) throws -> ProjectDTO {
    try decode(
        ##"{"id":"\##(id)","workspace":"\##(workspace)","name":"\##(name)","description":"","##
            + ##""color":"#a3a3a3","status":"active","due_date":null,"task_count":0}"##)
}

private func sampleSemester(id: String, name: String, start: String, end: String) throws -> SemesterDTO {
    try decode(
        ##"{"id":"\##(id)","name":"\##(name)","institution":"U","start_date":"\##(start)","##
            + ##""end_date":"\##(end)","status":"active","rotation_weeks":1,"rotation_anchor":null}"##)
}

private func sampleDiscipline(id: String, semester: String, name: String) throws -> DisciplineDTO {
    try decode(
        ##"{"id":"\##(id)","semester":"\##(semester)","name":"\##(name)","code":"C1","##
            + ##""professor":"","color":"#a3a3a3","credits":null,"status":"active"}"##)
}

/// One workspace, project, semester and discipline, cached as `load` reads them.
@MainActor
private func insertSampleLibrary(into context: ModelContext) throws {
    context.insert(
        WorkspaceRecord(dto: try sampleWorkspace(id: "11111111-1111-1111-1111-111111111111", name: "Client")))
    context.insert(
        ProjectRecord(
            dto: try sampleProject(
                id: "44444444-4444-4444-4444-444444444444", workspace: "11111111-1111-1111-1111-111111111111",
                name: "Thesis")))
    context.insert(
        SemesterRecord(
            dto: try sampleSemester(
                id: "22222222-2222-2222-2222-222222222222", name: "Fall", start: "2026-08-01", end: "2026-12-15")))
    context.insert(
        DisciplineRecord(
            dto: try sampleDiscipline(
                id: "33333333-3333-3333-3333-333333333333", semester: "22222222-2222-2222-2222-222222222222",
                name: "Calculus")))
}

/// Pins the place directory's selection (spec §2): active projects grouped
/// by workspace, the current semester's active disciplines, and how a
/// filing resolves to a title and colour.
struct PlaceDirectoryTests {
    @Test func currentSemesterPicksTheOneContainingToday() {
        let fall = SemesterSpan(
            id: "fall", name: "Fall", startDay: "2026-08-01", endDay: "2026-12-15", status: "active")
        let spring = SemesterSpan(
            id: "spring", name: "Spring", startDay: "2026-01-01", endDay: "2026-06-01", status: "active")
        #expect(PlaceDirectory.currentSemester([fall, spring], today: "2026-09-27") == fall)
    }

    @Test func currentSemesterFallsBackToTheLatestActiveWhenNoneContainsToday() {
        let recent = SemesterSpan(
            id: "recent", name: "Recent", startDay: "2025-08-01", endDay: "2025-12-15", status: "active")
        let older = SemesterSpan(
            id: "older", name: "Older", startDay: "2024-08-01", endDay: "2024-12-15", status: "active")
        #expect(PlaceDirectory.currentSemester([recent, older], today: "2026-09-27") == recent)
    }

    @Test func currentSemesterIsNilWhenNoneIsActive() {
        let archived = SemesterSpan(
            id: "old", name: "Old", startDay: "2025-08-01", endDay: "2025-12-15", status: "archived")
        #expect(PlaceDirectory.currentSemester([archived], today: "2026-09-27") == nil)
    }

    @Test func projectEntriesKeepOnlyActiveOnes() {
        let active = ProjectSpan(id: "p1", workspaceID: "w1", name: "Thesis", color: "#a3a3a3", status: "active")
        let paused = ProjectSpan(id: "p2", workspaceID: "w1", name: "Lab", color: "#a3a3a3", status: "paused")
        let entries = PlaceDirectory.projectEntries([active, paused], workspaceNames: ["w1": "Client"])
        #expect(entries.map(\.title) == ["Thesis"])
    }

    @Test func projectEntriesGroupByWorkspaceOnlyWhenThereIsMoreThanOne() {
        let project = ProjectSpan(id: "p1", workspaceID: "w1", name: "Thesis", color: "#a3a3a3", status: "active")
        let grouped = PlaceDirectory.projectEntries([project], workspaceNames: ["w1": "Client", "w2": "Lab"])
        let ungrouped = PlaceDirectory.projectEntries([project], workspaceNames: ["w1": "Client"])
        #expect(grouped.first?.group == "Client")
        #expect(ungrouped.first?.group == nil)
    }

    @Test func disciplineEntriesKeepOnlyTheChosenSemestersActiveOnes() {
        let here = DisciplineSpan(id: "d1", semesterID: "fall", name: "Calculus", color: "#a3a3a3", status: "active")
        let elsewhere = DisciplineSpan(
            id: "d2", semesterID: "spring", name: "History", color: "#a3a3a3", status: "active")
        let archived = DisciplineSpan(
            id: "d3", semesterID: "fall", name: "Physics", color: "#a3a3a3", status: "archived")
        let entries = PlaceDirectory.disciplineEntries([here, elsewhere, archived], semesterID: "fall")
        #expect(entries.map(\.title) == ["Calculus"])
    }

    @Test func placesForWorkAreItsProjects() {
        let entry = PlaceEntry(parent: .project("p1"), title: "Thesis", group: nil, color: KindTint.work)
        let directory = PlaceDirectory(projects: [entry], disciplines: [], semesterTitle: nil)
        #expect(directory.places(for: .work) == [entry])
    }

    @Test func placesForStudyAreItsDisciplines() {
        let entry = PlaceEntry(parent: .discipline("d1"), title: "Calculus", group: nil, color: KindTint.study)
        let directory = PlaceDirectory(projects: [], disciplines: [entry], semesterTitle: nil)
        #expect(directory.places(for: .study) == [entry])
    }

    @Test func placesForLifeIsEmpty() {
        #expect(PlaceDirectory.empty.places(for: .life) == [])
    }

    /// `ParentMenuChip` hides itself when this is empty (spec §4, S5 #258).
    @Test func anEmptyDirectoryHasNoPlacesForWorkOrStudy() {
        #expect(PlaceDirectory.empty.places(for: .work).isEmpty)
        #expect(PlaceDirectory.empty.places(for: .study).isEmpty)
    }

    @Test func markForAKnownParentUsesTheEntry() {
        let entry = PlaceEntry(parent: .project("p1"), title: "Thesis", group: nil, color: KindTint.work)
        let directory = PlaceDirectory(projects: [entry], disciplines: [], semesterTitle: nil)
        let mark = directory.mark(for: TaskFiling(area: .work, parent: .project("p1")))
        #expect(mark == KindMark(title: "Thesis", color: KindTint.work))
    }

    @Test func markForAnUnknownParentFallsBackToTheKind() {
        let mark = PlaceDirectory.empty.mark(for: TaskFiling(area: .work, parent: .project("gone")))
        #expect(mark == KindMark(title: "Work", color: KindTint.work))
    }

    @Test func markForNoParentIsTheKind() {
        let mark = PlaceDirectory.empty.mark(for: TaskFiling(area: .life, parent: nil))
        #expect(mark == KindMark(title: "Life", color: KindTint.life))
    }

    @Test func knownPlacesAlwaysIncludesLife() {
        #expect(PlaceDirectory.empty.knownPlaces == [.life])
    }

    @Test func knownPlacesListsEveryEntry() {
        let project = PlaceEntry(parent: .project("p1"), title: "Thesis", group: nil, color: KindTint.work)
        let discipline = PlaceEntry(parent: .discipline("d1"), title: "Calculus", group: nil, color: KindTint.study)
        let directory = PlaceDirectory(projects: [project], disciplines: [discipline], semesterTitle: nil)
        #expect(directory.knownPlaces == [.project("p1"), .discipline("d1"), .life])
    }

    @MainActor
    @Test func loadReadsTheLibraryCache() throws {
        // The container must outlive this scope (kept in a local), or
        // `mainContext` dangles once its container is deallocated.
        let container = try StoreSchema.container(inMemory: true)
        let context = container.mainContext
        try insertSampleLibrary(into: context)
        let directory = PlaceDirectory.load(from: context, today: "2026-09-27")
        #expect(directory.projects.map(\.title) == ["Thesis"])
        #expect(directory.projects.first?.group == nil)
        #expect(directory.disciplines.map(\.title) == ["Calculus"])
        #expect(directory.semesterTitle == "Fall")
    }

    /// The snapshot a view watches to know when to reload the directory
    /// (spec §8): equal for the same day and library rows, so a redraw the
    /// timer's tick causes does not trigger one.
    @MainActor
    @Test func theSnapshotChangesOnlyWhenTheDayOrALibraryRowChanges() throws {
        let container = try StoreSchema.container(inMemory: true)
        let context = container.mainContext
        try insertSampleLibrary(into: context)
        let projects = try context.fetch(FetchDescriptor<ProjectRecord>())
        let disciplines = try context.fetch(FetchDescriptor<DisciplineRecord>())
        let snapshot = PlaceLibrarySnapshot(today: "2026-09-27", projects: projects, disciplines: disciplines)

        #expect(snapshot == PlaceLibrarySnapshot(today: "2026-09-27", projects: projects, disciplines: disciplines))
        #expect(snapshot != PlaceLibrarySnapshot(today: "2026-09-28", projects: projects, disciplines: disciplines))

        projects.first?.name = "Renamed"
        #expect(snapshot != PlaceLibrarySnapshot(today: "2026-09-27", projects: projects, disciplines: disciplines))
    }

    /// `make` is what a screen's own `@Query` builds the directory from
    /// (spec §6, S6 #259), so it must read the same records `load` does.
    @MainActor
    @Test func makeBuildsTheSameDirectoryFromAlreadyFetchedRecords() throws {
        let container = try StoreSchema.container(inMemory: true)
        let context = container.mainContext
        try insertSampleLibrary(into: context)
        let directory = PlaceDirectory.make(
            workspaces: try context.fetch(FetchDescriptor<WorkspaceRecord>()),
            projects: try context.fetch(FetchDescriptor<ProjectRecord>()),
            semesters: try context.fetch(FetchDescriptor<SemesterRecord>()),
            disciplines: try context.fetch(FetchDescriptor<DisciplineRecord>()), today: "2026-09-27")
        #expect(directory.projects.map(\.title) == ["Thesis"])
        #expect(directory.disciplines.map(\.title) == ["Calculus"])
        #expect(directory.semesterTitle == "Fall")
    }

    @Test func placeForAProjectParentIsAProjectPlace() {
        #expect(PlaceDirectory.place(for: .project("p1")) == .project("p1"))
    }

    @Test func placeForADisciplineParentIsADisciplinePlace() {
        #expect(PlaceDirectory.place(for: .discipline("d1")) == .discipline("d1"))
    }
}
