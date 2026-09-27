import Foundation
import OmakaseFeatures
import OmakaseStore
import SwiftData

extension AppServices {
    /// Plan's range read and block writes (#203). Each write goes through the
    /// outbox in one `coordinator.write` and catches up at once, as Focus's
    /// do (#91); `onOutcome` sees the result. A failed range read shows
    /// nothing more: the toolbar's sync item already says the app is offline.
    func planActions(onOutcome: @escaping @MainActor (SyncCoordinator.Outcome) -> Void) -> PlanModel.Actions {
        let blocks = BlockWrites(context: container.mainContext)
        return PlanModel.Actions(
            refresh: { [self] days in Task { try? await refreshRange(days: days) } },
            create: { [self] taskID, placement in
                blockWrite(onOutcome) {
                    _ = try blocks.create(
                        taskID: taskID, studyBlockID: nil, day: placement.day, start: placement.startTime,
                        end: placement.endTime)
                }
            },
            move: { [self] id, placement in
                onBlock(id, onOutcome) {
                    try blocks.move($0, day: placement.day, start: placement.startTime, end: placement.endTime)
                }
            },
            delete: { [self] id in onBlock(id, onOutcome) { try blocks.delete($0) } })
    }

    /// The cached block by id; one a catch-up has just removed is left alone.
    private func onBlock(
        _ id: String, _ onOutcome: @escaping @MainActor (SyncCoordinator.Outcome) -> Void,
        _ write: @escaping (TimeBlockRecord) throws -> Void
    ) {
        let descriptor = FetchDescriptor<TimeBlockRecord>(predicate: #Predicate { $0.id == id })
        guard let record = try? container.mainContext.fetch(descriptor).first else { return }
        blockWrite(onOutcome) { try write(record) }
    }

    private func blockWrite(
        _ onOutcome: @escaping @MainActor (SyncCoordinator.Outcome) -> Void, _ write: @escaping () throws -> Void
    ) {
        let coordinator = self.coordinator
        Task { onOutcome((try? await coordinator.write { try write() }) ?? .synced) }
    }
}
