import SwiftUI

extension FocusedValues {
    /// The focused main window's capture context (spec §4): File › New Task
    /// ⌘N reads it, so the panel opens seeded from the screen on show. Nil
    /// with no window focused, which `CaptureContext.forCommand` turns into
    /// the default.
    @Entry public var newTaskContext: CaptureContext?
}
