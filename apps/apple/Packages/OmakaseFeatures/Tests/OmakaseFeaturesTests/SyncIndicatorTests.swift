import Foundation
import OmakaseStore
import Testing

@testable import OmakaseFeatures

struct SyncIndicatorTests {
    static func parked(_ kind: String, sequence: Int = 1) -> ParkedWrite {
        ParkedWrite(
            sequence: sequence, kind: kind, subjectID: "t1", lastError: "Not found.",
            createdAt: Date(timeIntervalSince1970: 0), method: "PATCH", path: "/api/v1/tasks/t1/")
    }

    static func status(pending: Int = 0, parked: [ParkedWrite] = []) -> OutboxStatus {
        OutboxStatus(pendingCount: pending, parked: parked, nextAttemptAt: nil)
    }

    @Test func onlineWithNothingQueuedIsSynced() {
        let indicator = SyncIndicator(isOnline: true, status: Self.status())
        #expect(indicator == .synced)
        #expect(indicator.symbol == "checkmark.icloud")
        #expect(indicator.label == "Synced")
        #expect(!indicator.opensFailedWrites)
    }

    @Test func offlineWithNothingQueuedSaysOffline() {
        let indicator = SyncIndicator(isOnline: false, status: Self.status())
        #expect(indicator == .offline(queued: 0))
        #expect(indicator.symbol == "icloud.slash")
        #expect(indicator.label == "Offline")
    }

    @Test func offlineWithWritesQueuedCountsThem() {
        let indicator = SyncIndicator(isOnline: false, status: Self.status(pending: 2))
        #expect(indicator == .offline(queued: 2))
        #expect(indicator.label == "Offline · 2 queued")
    }

    @Test func onlineWithWritesQueuedIsSyncing() {
        let indicator = SyncIndicator(isOnline: true, status: Self.status(pending: 3))
        #expect(indicator == .queued(3))
        #expect(indicator.symbol == "arrow.triangle.2.circlepath.icloud")
        #expect(indicator.label == "3 queued")
    }

    @Test func aParkedWriteTakesPriorityEvenOffline() {
        let parked = [Self.parked("task.patch"), Self.parked("block.patch", sequence: 2)]
        for online in [true, false] {
            let indicator = SyncIndicator(isOnline: online, status: Self.status(pending: 4, parked: parked))
            #expect(indicator == .failed(2))
            #expect(indicator.symbol == "exclamationmark.icloud")
            #expect(indicator.label == "2 failed")
            #expect(indicator.opensFailedWrites)
        }
    }

    @Test(arguments: [
        ("task.create", "Create task"), ("task.patch", "Update task"), ("subtask.patch", "Update subtask"),
        ("block.patch", "Update block"), ("block.create", "Create block"), ("block.delete", "Delete block"), ("task.delete", "Delete task"),
        ("session.create", "Record focus session"), ("review.put", "Save review"),
        ("task.materialize", "Save repeating task"), ("task.recurrence", "Set repeat"),
        ("task.recurrence.stop", "Stop repeat"),
        ("class.cancel", "Cancel class"), ("class.restore", "Restore class"),
    ])
    func eachKnownKindReadsAsAnAction(kind: String, expected: String) {
        #expect(Self.parked(kind).actionTitle == expected)
    }

    @Test func anUnknownKindReadsAsItself() {
        #expect(Self.parked("tag.delete").actionTitle == "tag.delete")
    }
}
