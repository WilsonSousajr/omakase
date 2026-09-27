import SwiftData
import Testing

@testable import OmakaseStore

/// A place's filing and its cached open tasks (spec §5): one definition
/// `PlaceSync`'s prune step and a place screen's `@Query` both read.
@MainActor
struct TaskPlaceTests {
    let container: ModelContainer

    init() throws { container = try StoreSchema.container(inMemory: true) }

    private var context: ModelContext { container.mainContext }

    @Test func aProjectFilesWorkUnderItself() {
        #expect(TaskPlace.project("p1").filing == TaskFiling(area: .work, parent: .project("p1")))
    }

    @Test func aDisciplineFilesStudyUnderItself() {
        #expect(TaskPlace.discipline("d1").filing == TaskFiling(area: .study, parent: .discipline("d1")))
    }

    @Test func lifeFilesWithNoParent() {
        #expect(TaskPlace.life.filing == TaskFiling(area: .life, parent: nil))
    }

    @Test func aProjectsOpenTasksMatchItsID() throws {
        _ = try makeTask(id: "t1", filing: TaskFiling(area: .work, parent: .project("p1")))
        _ = try makeTask(id: "t2", filing: TaskFiling(area: .work, parent: .project("p2")))
        #expect(try open(TaskPlace.project("p1")) == ["t1"])
    }

    @Test func aDisciplinesOpenTasksMatchItsID() throws {
        _ = try makeTask(id: "t1", filing: TaskFiling(area: .study, parent: .discipline("d1")))
        #expect(try open(TaskPlace.discipline("d1")) == ["t1"])
    }

    @Test func lifesOpenTasksAreThePersonalArea() throws {
        _ = try makeTask(id: "t1", filing: TaskFiling(area: .life, parent: nil))
        _ = try makeTask(id: "t2", filing: TaskFiling(area: .work, parent: nil))
        #expect(try open(TaskPlace.life) == ["t1"])
    }

    @Test func aCompletedTaskIsNotOpen() throws {
        _ = try makeTask(id: "t1", filing: TaskFiling(area: .work, parent: .project("p1")), isCompleted: true)
        #expect(try open(TaskPlace.project("p1")).isEmpty)
    }

    private func makeTask(id: String, filing: TaskFiling, isCompleted: Bool = false) throws -> TaskRecord {
        let record = TaskRecord(id: id, title: id, isCompleted: isCompleted, filing: filing)
        context.insert(record)
        try context.save()
        return record
    }

    private func open(_ place: TaskPlace) throws -> [String] {
        try context.fetch(FetchDescriptor<TaskRecord>(predicate: place.openTasksPredicate)).map(\.id)
    }
}
