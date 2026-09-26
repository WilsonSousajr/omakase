import SwiftUI

/// "Capture Task…" in the File menu, so ⌥⌘N is discoverable and works
/// while the app is active; signed out, there is nothing to capture into.
struct CaptureCommands: Commands {
    let capture: GlobalCapture?
    let isEnabled: Bool

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Capture Task…") { capture?.show() }
                .keyboardShortcut("n", modifiers: [.command, .option])
                .disabled(!isEnabled || capture == nil)
        }
    }
}
