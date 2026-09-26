import Foundation
import OmakaseAPI
import SwiftData
import Testing

@testable import OmakaseStore

@MainActor
struct OutboxMaintenanceTests {
    let container: ModelContainer
    let api = FakeAPIClient()
    let start = Date(timeIntervalSince1970: 1_772_884_800)
    var context: ModelContext { container.mainContext }
    var maintenance: OutboxMaintenance { OutboxMaintenance(context: context) }

    init() throws { container = try StoreSchema.container(inMemory: true) }

    func worker() -> OutboxWorker {
        OutboxWorker(
            context: context, api: api, clock: { [start] in start }, handlers: OutboxHandlers([RecordingHandler()]))
    }

    @discardableResult
    func enqueue(_ sequence: Int, _ path: String, creates: String? = nil) -> OutboxEntry {
        let entry = OutboxEntry(
            sequence: sequence, method: creates == nil ? "PATCH" : "POST", path: path, body: nil,
            subjectID: creates, createsLocalID: creates, kind: creates == nil ? "task.patch" : "task.create",
            now: start)
        context.insert(entry)
        return entry
    }

    func remaining() throws -> [OutboxEntry] {
        try context.fetch(FetchDescriptor<OutboxEntry>(sortBy: [SortDescriptor(\.sequence)]))
    }

    @Test func anEmptyOutboxHasNothingToShow() {
        #expect(maintenance.status() == OutboxStatus(pendingCount: 0, parked: [], nextAttemptAt: nil))
    }

    @Test func statusCountsPendingAndListsParked() throws {
        enqueue(1, "/a/")
        enqueue(2, "/b/").nextAttemptAt = start.addingTimeInterval(8)
        enqueue(3, "/c/").nextAttemptAt = start.addingTimeInterval(2)
        let parked = enqueue(4, "/d/")
        (parked.state, parked.lastError) = (.parked, "title required")
        let status = maintenance.status()
        #expect(status.pendingCount == 3)
        #expect(status.nextAttemptAt == start.addingTimeInterval(2))
        #expect(
            status.parked == [
                ParkedWrite(
                    sequence: 4, kind: "task.patch", subjectID: nil, lastError: "title required", createdAt: start,
                    method: "PATCH", path: "/d/")
            ])
    }
}
