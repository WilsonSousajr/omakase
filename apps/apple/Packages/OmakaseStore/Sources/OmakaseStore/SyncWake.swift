import Foundation

/// Asks for `fire` to run at a date, and returns the wake that can call it off.
/// Injected into `SyncCoordinator` so tests fire a backoff's wake at once.
public typealias SyncWakeScheduler = @MainActor (Date, @escaping @MainActor () async -> Void) -> SyncWake

/// One scheduled catch-up, which the coordinator cancels when a newer drain
/// makes it stale (M3.5 spec, Decisions: backoff wakes itself).
///
///     let wake = SyncWake.sleeping(until: due) { await coordinator.catchUp() }
///     wake.cancel()
@MainActor
public struct SyncWake {
    private let onCancel: @MainActor () -> Void

    public init(cancel: @escaping @MainActor () -> Void) { onCancel = cancel }

    public func cancel() { onCancel() }

    /// The app's scheduler: a task that sleeps until `date`, then fires unless it was cancelled first.
    @discardableResult
    public static func sleeping(until date: Date, fire: @escaping @MainActor () async -> Void) -> SyncWake {
        let sleeper = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(max(date.timeIntervalSinceNow, 0)))
            } catch {
                return
            }
            await fire()
        }
        return SyncWake { sleeper.cancel() }
    }
}
