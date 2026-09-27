import Foundation
import OmakaseFeatures
import OmakaseStore
import SwiftData

extension AppServices {
    /// Plan's range read, block writes (#203) and class cancellations (#207).
    /// Each write goes through the outbox in one `coordinator.write` and
    /// catches up at once, as Focus's do (#91); `onOutcome` sees the result.
    /// A failed range read shows nothing more: the toolbar's sync item
    /// already says the app is offline. A slot drawn on the grid opens
    /// capture through `openCapture`, as ⌘N and ＋ do (spec §9, #264).
    func planActions(
        openCapture: @escaping (CaptureContext) -> Void,
        onOutcome: @escaping @MainActor (SyncCoordinator.Outcome) -> Void
    ) -> PlanModel.Actions {
        let blocks = BlockWrites(context: container.mainContext)
        let classes = ClassWrites(context: container.mainContext)
        return PlanModel.Actions(
            refresh: { [self] days in Task { try? await refreshRange(days: days) } },
            create: { [self] taskID, placement in
                planWrite(onOutcome) {
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
            delete: { [self] id in onBlock(id, onOutcome) { try blocks.delete($0) } },
            cancelClass: { [self] id in onClass(id, onOutcome) { try classes.cancel($0) } },
            restoreClass: { [self] id in onClass(id, onOutcome) { try classes.restore($0) } },
            capture: { openCapture(CaptureContext(slot: $0)) })
    }

    /// The Calendar.app overlay (#229), its toggle kept in UserDefaults.
    func makeCalendarOverlay(defaults: UserDefaults = .standard) -> CalendarOverlayModel {
        let key = "omakase.calendarOverlay"
        return CalendarOverlayModel(
            source: EventKitCalendar(), isStored: { defaults.bool(forKey: key) },
            store: { defaults.set($0, forKey: key) })
    }

    /// The cached block by id; one a catch-up has just removed is left alone.
    private func onBlock(
        _ id: String, _ onOutcome: @escaping @MainActor (SyncCoordinator.Outcome) -> Void,
        _ write: @escaping (TimeBlockRecord) throws -> Void
    ) {
        let descriptor = FetchDescriptor<TimeBlockRecord>(predicate: #Predicate { $0.id == id })
        guard let record = try? container.mainContext.fetch(descriptor).first else { return }
        planWrite(onOutcome) { try write(record) }
    }

    /// The cached class occurrence by id, as `onBlock` (#207).
    private func onClass(
        _ id: String, _ onOutcome: @escaping @MainActor (SyncCoordinator.Outcome) -> Void,
        _ write: @escaping (ClassOccurrenceRecord) throws -> Void
    ) {
        let descriptor = FetchDescriptor<ClassOccurrenceRecord>(predicate: #Predicate { $0.id == id })
        guard let record = try? container.mainContext.fetch(descriptor).first else { return }
        planWrite(onOutcome) { try write(record) }
    }

    private func planWrite(
        _ onOutcome: @escaping @MainActor (SyncCoordinator.Outcome) -> Void, _ write: @escaping () throws -> Void
    ) {
        let coordinator = self.coordinator
        Task { onOutcome((try? await coordinator.write { try write() }) ?? .synced) }
    }
}
