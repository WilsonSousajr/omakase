import OmakaseFeatures

/// Capture from anywhere (spec, Global capture): the ⌥⌘N hotkey and the
/// panel it opens, on only while signed in, since a capture made signed out
/// would queue a write no account can send.
///
///     let capture = GlobalCapture { title, destination in services.capture(title, to: destination) }
///     capture.setEnabled(signedIn)
@MainActor
final class GlobalCapture {
    private let panel: CapturePanelController
    private var hotKey: GlobalHotKey?

    init(onCapture: @escaping (String, CaptureDestination) -> Void) {
        panel = CapturePanelController(onCapture: onCapture)
    }

    /// Registers the hotkey on sign-in; unregisters it and closes any open panel on sign-out.
    func setEnabled(_ isEnabled: Bool) {
        guard isEnabled else { return disable() }
        guard hotKey == nil else { return }
        let panel = self.panel
        hotKey = GlobalHotKey.capture { panel.show() }
    }

    func show() { panel.show() }

    private func disable() {
        hotKey?.unregister()
        hotKey = nil
        panel.close()
    }
}
