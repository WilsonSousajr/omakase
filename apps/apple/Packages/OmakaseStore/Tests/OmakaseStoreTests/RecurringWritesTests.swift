import Foundation
import OmakaseAPI
import SwiftData
import Testing

@testable import OmakaseStore

/// Writes on a repeating task (#206): the first write on a computed
/// occurrence materializes it, and the rule is set or stopped by the outbox.
@MainActor
struct RecurringWritesTests {
    let container: ModelContainer
    let api = FakeAPIClient()
    let series = UUID()
    var context: ModelContext { container.mainContext }
    var occurrenceID: String { "occ-\(series.uuidString)-2026-03-04" }

    init() throws { container = try StoreSchema.container(inMemory: true) }

    func computed(day: String = "2026-03-04") -> TaskRecord {
        let record = TaskRecord(id: "occ-\(series.uuidString)-\(day)", title: "Stand-up", scheduledDay: day)
        (record.seriesID, record.occurrenceDay, record.isVirtual) = (series.uuidString, day, true)
        context.insert(record)
        return record
    }

    func entries() throws -> [OutboxEntry] {
        try context.fetch(FetchDescriptor<OutboxEntry>(sortBy: [SortDescriptor(\.sequence)]))
    }

    func tasks() throws -> [TaskRecord] {
        try context.fetch(FetchDescriptor<TaskRecord>(sortBy: [SortDescriptor(\.id)]))
    }

    func body(_ entry: OutboxEntry) -> String { String(bytes: entry.body ?? Data(), encoding: .utf8) ?? "" }

    func worker() -> OutboxWorker {
        OutboxWorker(
            context: context, api: api,
            handlers: OutboxHandlers([
                TaskHandler(context: context), RecurrenceHandler(context: context), BlockHandler(context: context),
            ]))
    }

    func reply(_ dto: TaskDTO) throws -> String { String(bytes: try OmakaseJSON.encoder.encode(dto), encoding: .utf8)! }

    @Test func completingAComputedOccurrenceMaterializesItWithTheCompletion() throws {
        let record = computed()
        try TaskWrites(context: context).toggleCompletion(record)
        let entry = try #require(try entries().first)
        #expect(try entries().count == 1 && entry.kind == "task.materialize" && entry.method == "PUT")
        #expect(entry.path == "/api/v1/tasks/\(series.uuidString)/occurrences/2026-03-04/")
        #expect(body(entry) == #"{"is_completed":true}"#)
        #expect(entry.createsLocalID == occurrenceID && entry.subjectID == occurrenceID)
        #expect(!record.isVirtual && record.isCompleted)
    }

    @Test func aSecondWriteIsAPatchOnTheOccurrenceID() throws {
        let record = computed()
        let writes = TaskWrites(context: context)
        try writes.toggleCompletion(record)
        try writes.reschedule(record, to: "2026-03-05")
        let patch = try #require(try entries().last)
        #expect(patch.kind == "task.patch" && patch.path == "/api/v1/tasks/\(occurrenceID)/")
    }

    @Test func anAcceptedMaterializeGivesTheRecordAndLaterWritesTheServerID() async throws {
        let record = computed()
        let writes = TaskWrites(context: context)
        try writes.toggleCompletion(record)
        try writes.reschedule(record, to: "2026-03-05")
        let row = UUID()
        let stored = try TaskDTO.make(id: row, title: "Stand-up", day: "2026-03-04", completed: true, series: series)
        await api.script([.reply(201, try reply(stored)), .reply(200, try reply(stored))])
        #expect(await worker().drain() == .empty)
        #expect(await api.sentRequests.last?.path == "/api/v1/tasks/\(row.uuidString)/")
        #expect(record.id == row.uuidString && !record.isVirtual && record.seriesID == series.uuidString)
    }

    @Test func aBlockOnAComputedOccurrenceMaterializesItFirst() throws {
        _ = computed()
        _ = try BlockWrites(context: context).create(
            taskID: occurrenceID, studyBlockID: nil, day: "2026-03-04", start: "09:00:00", end: "10:00:00")
        let queued = try entries()
        #expect(queued.map(\.kind) == ["task.materialize", "block.create"])
        #expect(body(queued[0]) == "{}" && body(queued[1]).contains(occurrenceID))
        #expect(OutboxRules.dependents(of: queued[0], among: queued).map(\.kind) == ["block.create"])
    }

    @Test func discardingAParkedMaterializeRevertsTheOccurrence() async throws {
        let record = computed()
        let writes = TaskWrites(context: context)
        try writes.toggleCompletion(record)
        try writes.reschedule(record, to: "2026-03-05")
        await api.script([.reply(400, #"{"detail":"2026-03-04 is not an occurrence"}"#)])
        _ = await worker().drain()
        let parked = try #require(try entries().first)
        try OutboxMaintenance(context: context).discard(sequence: parked.sequence)
        // Gone until the next refresh brings the computed occurrence back.
        #expect(try entries().isEmpty && tasks().isEmpty)
    }

    @Test func settingARuleOnAPlainTaskPutsIt() throws {
        let record = TaskRecord(id: "t1", title: "Gym", scheduledDay: "2026-03-04")
        context.insert(record)
        let rule = RepeatRule(freq: .weekly, weekdays: [2], startsOn: "2026-03-04")
        try TaskWrites(context: context).setRecurrence(record, rule: rule)
        let entry = try #require(try entries().first)
        #expect(entry.kind == "task.recurrence" && entry.method == "PUT" && entry.subjectID == "t1")
        #expect(entry.path == "/api/v1/tasks/t1/recurrence/")
        #expect(body(entry) == #"{"freq":"weekly","interval":1,"starts_on":"2026-03-04","until":null,"weekdays":[2]}"#)
    }

    @Test func settingARuleOnAComputedOccurrenceTargetsItsSeries() throws {
        let record = computed()
        try TaskWrites(context: context).setRecurrence(record, rule: RepeatRule(freq: .daily, startsOn: "2026-03-04"))
        let entry = try #require(try entries().first)
        #expect(try entries().count == 1 && entry.path == "/api/v1/tasks/\(series.uuidString)/recurrence/")
        #expect(record.isVirtual)
    }

    @Test func anAcceptedRuleJoinsTheTaskToItsSeries() async throws {
        let id = UUID()
        let record = TaskRecord(id: id.uuidString, title: "Gym", scheduledDay: "2026-03-04")
        context.insert(record)
        try TaskWrites(context: context).setRecurrence(record, rule: RepeatRule(freq: .daily, startsOn: "2026-03-04"))
        await api.script([.reply(200, try reply(try .make(id: id, title: "Gym", day: "2026-03-04", series: series)))])
        #expect(await worker().drain() == .empty)
        #expect(record.seriesID == series.uuidString && record.isRepeating)
    }

    @Test func aRuleSetThroughTheSeriesAddsNoTemplateToTheCache() async throws {
        let record = computed()
        try TaskWrites(context: context).setRecurrence(record, rule: RepeatRule(freq: .daily, startsOn: "2026-03-04"))
        await api.script([.reply(200, try reply(try .make(id: series, title: "Stand-up", day: nil)))])
        #expect(await worker().drain() == .empty)
        #expect(try tasks().map(\.id) == [occurrenceID])
    }

    @Test func stoppingDeletesTheRuleFromTheClientsDay() throws {
        let record = TaskRecord(id: "t1", title: "Gym", scheduledDay: "2026-03-04")
        record.seriesID = series.uuidString
        context.insert(record)
        try TaskWrites(context: context).stopRecurrence(record, today: "2026-03-07")
        let entry = try #require(try entries().first)
        #expect(entry.kind == "task.recurrence.stop" && entry.method == "DELETE" && entry.body == nil)
        #expect(entry.path == "/api/v1/tasks/t1/recurrence/?date=2026-03-07")
    }

    @Test func stoppingFromAComputedOccurrenceTargetsItsSeries() throws {
        let record = computed(day: "2026-03-02")
        try TaskWrites(context: context).stopRecurrence(record, today: "2026-03-07")
        #expect(try entries().first?.path == "/api/v1/tasks/\(series.uuidString)/recurrence/?date=2026-03-07")
    }

    @Test func stoppingHidesTheSeriesComputedOccurrencesFromToday() throws {
        let past = computed(day: "2026-03-02")
        _ = computed(day: "2026-03-07")
        _ = computed(day: "2026-03-09")
        let other = TaskRecord(id: "occ-other-2026-03-09", title: "Other", scheduledDay: "2026-03-09")
        (other.seriesID, other.isVirtual) = ("other", true)
        context.insert(other)
        try TaskWrites(context: context).stopRecurrence(past, today: "2026-03-07")
        #expect(try tasks().map(\.id).sorted() == [past.id, other.id].sorted())
    }

    @Test func anAcceptedStopIsNotParked() async throws {
        let record = TaskRecord(id: "t1", title: "Gym")
        context.insert(record)
        try TaskWrites(context: context).stopRecurrence(record, today: "2026-03-07")
        await api.script([.reply(204, "")])
        #expect(await worker().drain() == .empty)
        #expect(try entries().isEmpty && record.title == "Gym")
    }
}
