import OmakaseFeatures
import SwiftUI

/// File › New Task ⌘N and File › Capture Task…, so capture is discoverable
/// and works while the app is active; signed out, there is nothing to
/// capture into. ⌘N replaces SwiftUI's New Window (spec §4) and opens the
/// panel with the focused window's context, or the default with no window;
/// ⌥⌘N, the global hotkey's chord, always opens with the default.
struct CaptureCommands: Commands {
    let capture: GlobalCapture?
    let isEnabled: Bool
    @FocusedValue(\.newTaskContext) private var focusedContext

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Task") { capture?.show(context: .forCommand(focused: focusedContext)) }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(isDisabled)
            Button("Capture Task…") { capture?.show(context: CaptureContext()) }
                .keyboardShortcut("n", modifiers: [.command, .option])
                .disabled(isDisabled)
        }
    }

    private var isDisabled: Bool { !isEnabled || capture == nil }
}
