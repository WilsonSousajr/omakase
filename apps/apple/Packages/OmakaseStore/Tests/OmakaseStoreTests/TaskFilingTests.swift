import Testing

@testable import OmakaseStore

/// The kind and parent a task files under (spec §1): the store derives the
/// kind in one place, so a project always reads as Work and a discipline as
/// Study, even when the server holds an inconsistent row.
struct TaskFilingTests {
    @Test func workWithNoParentStaysWork() {
        #expect(TaskFiling(area: .work, parent: nil).area == .work)
    }

    @Test func lifeWithNoParentStaysLifeAndWiresAsPersonal() {
        #expect(TaskFiling(area: .life, parent: nil).area == .life)
        #expect(TaskArea.life.rawValue == "personal")
    }

    @Test func workWithADisciplineIsDerivedAsStudy() {
        #expect(TaskFiling(area: .work, parent: .discipline("d1")).area == .study)
    }

    @Test func lifeWithAProjectIsDerivedAsWork() {
        #expect(TaskFiling(area: .life, parent: .project("p1")).area == .work)
    }

    @Test func anUnknownWireAreaReadsAsWork() {
        #expect(TaskArea(wire: "leisure") == .work)
    }

    @Test func theWireValuePersonalReadsAsLife() {
        #expect(TaskArea(wire: "personal") == .life)
    }

    @Test func aDisciplineWinsOverAProjectWhenBothAreSet() {
        let filing = TaskFiling(areaWire: "work", projectID: "p", disciplineID: "d")
        #expect(filing.area == .study && filing.parent == .discipline("d"))
    }

    @Test func anInconsistentServerRowShowsAsStudy() {
        // area "work" with a discipline set: the backend doesn't enforce the
        // match (spec §1, "Not in M9"), so the store's derivation wins.
        let filing = TaskFiling(areaWire: "work", projectID: nil, disciplineID: "d")
        #expect(filing.area == .study)
    }

    @Test func noParentIDsMeansNoParent() {
        let filing = TaskFiling(areaWire: "personal", projectID: nil, disciplineID: nil)
        #expect(filing.area == .life && filing.parent == nil)
    }

    // MARK: Choosing a kind, dropping a mismatched parent (S5, #258)

    @Test func choosingADisciplinesKindKeepsTheDiscipline() {
        let filing = TaskFiling.choosing(.study, keeping: .discipline("d1"))
        #expect(filing == TaskFiling(area: .study, parent: .discipline("d1")))
    }

    @Test(arguments: [TaskArea.work, .life])
    func choosingAnotherKindDropsTheDiscipline(area: TaskArea) {
        let filing = TaskFiling.choosing(area, keeping: .discipline("d1"))
        #expect(filing == TaskFiling(area: area, parent: nil))
    }

    @Test(arguments: [TaskArea.study, .life])
    func choosingAnotherKindDropsTheProject(area: TaskArea) {
        let filing = TaskFiling.choosing(area, keeping: .project("p1"))
        #expect(filing == TaskFiling(area: area, parent: nil))
    }

    @Test func choosingWithNoParentStaysWithNoParent() {
        #expect(TaskFiling.choosing(.life, keeping: nil) == TaskFiling(area: .life, parent: nil))
    }
}
