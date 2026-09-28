import Foundation
import OmakaseFeatures
import OmakaseStore

extension AppServices {
    /// The last kind a capture used (spec §4), kept beside `omakase.calendarOverlay`.
    private static let captureAreaKey = "omakase.capture.area"
    /// Whether the panel was left expanded by ⌘E (glass-pass §4, #286).
    private static let captureExpandedKey = "omakase.capture.expanded"

    /// The capture panel's writes (spec §4): each save goes through the
    /// store, so it works offline (M3.5 spec, Decisions), and its kind is
    /// remembered for the next opening, as is whether it was expanded.
    func captureActions(
        defaults: UserDefaults = .standard, onOutcome: @escaping @MainActor (SyncCoordinator.Outcome) -> Void
    ) -> CaptureModel.Actions {
        CaptureModel.Actions(
            capture: { [self] request in capture(request, onOutcome: onOutcome) },
            remember: { area in defaults.set(area.rawValue, forKey: Self.captureAreaKey) },
            rememberExpanded: { isExpanded in defaults.set(isExpanded, forKey: Self.captureExpandedKey) })
    }

    /// The kind a capture opens with when its context names none; Work until the first save.
    func lastCaptureArea(defaults: UserDefaults = .standard) -> TaskArea {
        TaskArea(storedRaw: defaults.string(forKey: Self.captureAreaKey))
    }

    /// Whether a new panel opens expanded: as the last one was left, collapsed until then.
    func captureOpensExpanded(defaults: UserDefaults = .standard) -> Bool {
        CaptureExpansion.isExpanded(stored: defaults.object(forKey: Self.captureExpandedKey))
    }

    /// The places the panel offers, read from the library cache each time it
    /// opens: the panel is its own root, with none of the window's environment (#214).
    func capturePlaces() -> PlaceDirectory {
        PlaceDirectory.load(from: container.mainContext, today: FocusDay().today)
    }

    /// A capture saved through the store: Today takes the user's local day,
    /// Plan's day or slot that day, the Inbox none. A drawn slot's block
    /// joins the same write (spec §9, #264): queued after the task and naming
    /// its `local-` id, which `OutboxWorker` rewrites once the task is
    /// accepted; a parked task parks it too. ⌘E's subtasks follow it the same
    /// way (#286), all through the one Store helper `captureTask`. The write
    /// then catches up at once, as Focus's writes do (#91).
    private func capture(
        _ request: CaptureRequest, onOutcome: @escaping @MainActor (SyncCoordinator.Outcome) -> Void
    ) {
        let day = request.destination.scheduledDay(today: FocusDay().today)
        let (coordinator, writes) = (self.coordinator, self.writes)
        Task {
            do {
                let outcome = try await coordinator.write {
                    try writes.captureTask(
                        title: request.title, day: day, filing: request.filing, details: request.details,
                        slot: request.destination.captureSlot)
                }
                onOutcome(outcome)
            } catch {
                // Reported, not swallowed as synced (S11's review, #286): a
                // `TaskCaptureError` says the task was saved without its block or subtasks.
                onOutcome(.failed(String(describing: error)))
            }
        }
    }
}
