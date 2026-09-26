import OmakaseFeatures
import OmakaseStore

extension AppServices {
    /// A capture saved through the store, so it works offline (M3.5 spec,
    /// Decisions): Today takes the user's local day, the Inbox none. The
    /// write then catches up at once, as Focus's writes do (#91).
    func capture(
        _ title: String, to destination: CaptureDestination,
        onOutcome: @escaping @MainActor (SyncCoordinator.Outcome) -> Void
    ) {
        let day = destination == .today ? FocusDay().today : nil
        let (coordinator, writes) = (self.coordinator, self.writes)
        Task { onOutcome((try? await coordinator.write { _ = try writes.capture(title: title, day: day) }) ?? .synced) }
    }
}
