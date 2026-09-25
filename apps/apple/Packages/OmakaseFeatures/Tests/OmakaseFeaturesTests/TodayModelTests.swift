import Foundation
import OmakaseStore
import SwiftData
import Testing

@testable import OmakaseFeatures

@MainActor
struct TodayModelTests {
    func record(_ title: String, _ priority: String, done: Bool = false) -> TaskRecord {
        TaskRecord(id: UUID().uuidString, title: title, priority: priority, isCompleted: done)
    }

    @Test func incompleteFirstThenPriorityThenTitle() {
        let rows = TodayModel.rows([
            record("b", "low"), record("done", "urgent", done: true), record("a", "low"), record("z", "urgent"),
        ])
        #expect(rows.map(\.title) == ["z", "a", "b", "done"])
    }

    @Test func anUnknownPrioritySortsLast() {
        let rows = TodayModel.rows([record("odd", "someday"), record("low one", "low")])
        #expect(rows.map(\.title) == ["low one", "odd"])
    }
}
