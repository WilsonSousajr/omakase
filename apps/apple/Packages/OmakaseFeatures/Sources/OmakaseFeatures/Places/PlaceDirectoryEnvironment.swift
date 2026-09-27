import SwiftUI

extension EnvironmentValues {
    /// The place directory in scope for this view hierarchy (spec §2);
    /// `.empty` until a screen loads one from the library cache.
    @Entry public var placeDirectory: PlaceDirectory = .empty
}
