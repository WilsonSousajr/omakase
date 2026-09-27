import Foundation
import OmakaseFeatures
import OmakaseStore

extension AppServices {
    /// The last kind a capture used (spec §4), kept beside `omakase.calendarOverlay`.
    private static let captureAreaKey = "omakase.capture.area"

    /// The capture panel's writes (spec §4): each save goes through the
    /// store, so it works offline (M3.5 spec, Decisions), and its kind is
    /// remembered for the next opening.
    func captureActions(
        defaults: UserDefaults = .standard, onOutcome: @escaping @MainActor (SyncCoordinator.Outcome) -> Void
    ) -> CaptureModel.Actions {
        CaptureModel.Actions(
            capture: { [self] request in capture(request, onOutcome: onOutcome) },
            remember: { area in defaults.set(area.rawValue, forKey: Self.captureAreaKey) })
    }

    /// The kind a capture opens with when its context names none; Work until the first save.
    func lastCaptureArea(defaults: UserDefaults = .standard) -> TaskArea {
        TaskArea(storedRaw: defaults.string(forKey: Self.captureAreaKey))
    }

    /// The places the panel offers, read from the library cache each time it
    /// opens: the panel is its own root, with none of the window's environment (#214).
    func capturePlaces() -> PlaceDirectory {
        PlaceDirectory.load(from: container.mainContext, today: FocusDay().today)
    }

    /// A capture saved through the store: Today takes the user's local day,
    /// Plan's day or slot that day, the Inbox none. The write then catches up
    /// at once, as Focus's writes do (#91).
    private func capture(
        _ request: CaptureRequest, onOutcome: @escaping @MainActor (SyncCoordinator.Outcome) -> Void
    ) {
        // S11 (#264) adds the slot's block in the same write; until then a slot saves its day.
        let day = request.destination.scheduledDay(today: FocusDay().today)
        let (coordinator, writes) = (self.coordinator, self.writes)
        Task {
            let outcome = try? await coordinator.write {
                _ = try writes.capture(title: request.title, day: day, filing: request.filing)
            }
            onOutcome(outcome ?? .synced)
        }
    }
}
