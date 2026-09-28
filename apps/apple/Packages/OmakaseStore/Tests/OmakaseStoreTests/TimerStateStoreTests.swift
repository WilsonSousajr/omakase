import Foundation
import SwiftData
import Testing

@testable import OmakaseStore

@MainActor
struct TimerStateStoreTests {
    let container: ModelContainer
    init() throws { container = try StoreSchema.container(inMemory: true) }

    @Test func nothingSavedLoadsNil() {
        #expect(TimerStateStore(context: container.mainContext).load() == nil)
    }

    @Test func theLastSaveIsWhatLoads() throws {
        let store = TimerStateStore(context: container.mainContext)
        try store.save(Data("one".utf8))
        try store.save(Data("two".utf8))
        #expect(store.load() == Data("two".utf8))
        #expect(try container.mainContext.fetch(FetchDescriptor<TimerStateRecord>()).count == 1)
    }

    @Test func aSaveSurvivesANewContext() throws {
        // The spec: the running pomodoro survives a quit.
        try TimerStateStore(context: container.mainContext).save(Data("running".utf8))
        #expect(TimerStateStore(context: ModelContext(container)).load() == Data("running".utf8))
    }
}
