import Foundation
import OmakaseAPI
import SwiftData
import Testing

@testable import OmakaseStore

/// The task editor's save (#218): the record changes at once, and one PATCH
/// carries only the changed keys, with explicit nulls for what was cleared.
@MainActor
struct TaskEditTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws { container = try StoreSchema.container(inMemory: true) }

    func seeded() throws -> TaskRecord {
        let record = TaskRecord(dto: try .make(title: "Draft essay"))
        (record.estimatedMinutes, record.dueDay) = (30, "2026-03-09")
        context.insert(record)
        try context.save()
        return record
    }

    func bodies() throws -> [String] {
        try context.fetch(FetchDescriptor<OutboxEntry>(sortBy: [SortDescriptor(\.sequence)]))
            .map { String(bytes: $0.body ?? Data(), encoding: .utf8) ?? "" }
    }

    @Test func anEditQueuesOnePatchWithOnlyTheChangedKeys() throws {
        let record = try seeded()
        try TaskWrites(context: context).edit(record, changes: TaskEdit(title: "Final essay", priority: "urgent"))
        let entry = try #require(try context.fetch(FetchDescriptor<OutboxEntry>()).first)
        #expect(entry.kind == "task.patch" && entry.method == "PATCH" && entry.subjectID == record.id)
        #expect(entry.path == "/api/v1/tasks/\(record.id)/")
        #expect(try bodies() == [#"{"priority":"urgent","title":"Final essay"}"#])
        #expect(record.title == "Final essay" && record.priority == "urgent" && record.estimatedMinutes == 30)
    }

    @Test func clearingTheEstimateAndDueDateSendsExplicitNulls() throws {
        // An omitted key would leave the server's estimate and deadline set.
        let record = try seeded()
        try TaskWrites(context: context).edit(record, changes: TaskEdit(estimate: .clear, dueDay: .clear))
        #expect(try bodies() == [#"{"due_date":null,"estimated_minutes":null}"#])
        #expect(record.estimatedMinutes == nil && record.dueDay == nil)
    }

    @Test func settingTheEstimateDueDateAndNotesSendsTheirValues() throws {
        let record = try seeded()
        let changes = TaskEdit(notes: "Cite two sources", estimate: .set(45), dueDay: .set("2026-03-12"))
        try TaskWrites(context: context).edit(record, changes: changes)
        #expect(
            try bodies() == [#"{"description":"Cite two sources","due_date":"2026-03-12","estimated_minutes":45}"#])
        #expect(record.notes == "Cite two sources" && record.estimatedMinutes == 45 && record.dueDay == "2026-03-12")
    }

    @Test func aBlankTitleIsRejectedWithTheValue() throws {
        let record = try seeded()
        #expect(throws: TaskEditError.blankTitle("   ")) {
            try TaskWrites(context: context).edit(record, changes: TaskEdit(title: "   "))
        }
        #expect(record.title == "Draft essay")
        #expect(try bodies().isEmpty)
    }

    @Test func theBlankTitleErrorNamesTheValueAndTheExpectedShape() {
        let message = TaskEditError.blankTitle(" ").description
        #expect(message.contains(#"" ""#) && message.contains("non-blank"))
    }

    @Test func anEditThatChangesNothingQueuesNothing() throws {
        let record = try seeded()
        let changes = TaskEdit()
        #expect(changes.isEmpty)
        try TaskWrites(context: context).edit(record, changes: changes)
        #expect(try bodies().isEmpty)
    }

    @Test func aRefreshKeepsTheEditWhileItIsQueued() async throws {
        let api = FakeAPIClient()
        await api.setProfile(try .make())
        let server = try TaskDTO.make(title: "Draft essay")
        await api.setTasks([server], on: "2026-03-07")
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = .gmt
        let sync = DaySync(
            context: context, api: api, clock: { Date(timeIntervalSince1970: 1_772_884_800) }, calendar: utc)
        try await sync.refresh()
        let record = try #require(try context.fetch(FetchDescriptor<TaskRecord>()).first)
        try TaskWrites(context: context).edit(record, changes: TaskEdit(title: "Final essay"))
        try await sync.refresh()
        #expect(record.title == "Final essay")
    }
}
