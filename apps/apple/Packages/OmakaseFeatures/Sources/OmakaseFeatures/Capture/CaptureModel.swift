import Foundation
import Observation

/// Where a capture lands (M3.5 spec, Decisions): Today by default, because
/// no Inbox screen exists yet and an undated task would vanish until M5.
public enum CaptureDestination: Equatable, Sendable {
    case today, inbox

    public var title: String {
        switch self {
        case .today: "Today"
        case .inbox: "Inbox"
        }
    }
}

/// The ⌥⌘N capture panel's draft. The write is injected, so the app sends it
/// through the store (it works offline) and tests record it.
///
///     let model = CaptureModel(actions: .init(capture: { title, destination in … }))
///     model.draft = "Email the advisor"
///     model.save(to: .today)  // true, and the draft is empty again
@Observable
@MainActor
public final class CaptureModel {
    /// The write a save asks for: the trimmed title and where it lands.
    public struct Actions {
        let capture: (String, CaptureDestination) -> Void

        public init(capture: @escaping (String, CaptureDestination) -> Void) { self.capture = capture }
    }

    /// What Enter does; ⌘⏎ does the other.
    public static let enterDestination = CaptureDestination.today
    public static let hint = "⏎ \(CaptureDestination.today.title) · ⌘⏎ \(CaptureDestination.inbox.title) · ⎋ dismiss"

    public var draft = ""

    @ObservationIgnored private let actions: Actions

    public init(actions: Actions) { self.actions = actions }

    /// Saves the draft to `destination` and clears it; an empty or
    /// whitespace-only title saves nothing and returns false.
    @discardableResult
    public func save(to destination: CaptureDestination) -> Bool {
        let title = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return false }
        actions.capture(title, destination)
        draft = ""
        return true
    }

    /// Drops the draft: the panel is closed, never hidden, so nothing stale returns.
    public func dismiss() { draft = "" }
}
