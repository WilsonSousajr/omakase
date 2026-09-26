import Observation

/// Where a capture lands.
public enum CaptureDestination: Equatable, Sendable {
    case today, inbox

    public var title: String { "" }
}

/// The ⌥⌘N capture panel's draft (stub: #186's test comes first).
@Observable
@MainActor
public final class CaptureModel {
    public struct Actions {
        let capture: (String, CaptureDestination) -> Void

        public init(capture: @escaping (String, CaptureDestination) -> Void) { self.capture = capture }
    }

    public static let enterDestination = CaptureDestination.inbox
    public static let hint = ""

    public var draft = ""

    @ObservationIgnored private let actions: Actions

    public init(actions: Actions) { self.actions = actions }

    @discardableResult
    public func save(to destination: CaptureDestination) -> Bool { false }

    public func dismiss() {}
}
