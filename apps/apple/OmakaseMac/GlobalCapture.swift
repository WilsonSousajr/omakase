import OmakaseFeatures
import OmakaseStore

/// Capture from anywhere (spec, Global capture): the ⌥⌘N hotkey and the
/// panel it opens, on only while signed in, since a capture made signed out
/// would queue a write no account can send. ⌘N and the toolbar's ＋ open the
/// same panel with the window's context (spec §4).
///
///     let capture = GlobalCapture(
///         actions: services.captureActions { handle($0) }, directory: { services.capturePlaces() },
///         lastArea: { services.lastCaptureArea() }, isExpanded: { services.captureOpensExpanded() })
///     capture.setEnabled(signedIn)
@MainActor
final class GlobalCapture {
    private let panel: CapturePanelController
    private let directory: () -> PlaceDirectory
    private let lastArea: () -> TaskArea
    private let isExpanded: () -> Bool
    private var hotKey: GlobalHotKey?

    /// `directory`, `lastArea` and `isExpanded` are read at each opening, so
    /// the panel offers the places cached now, the kind last saved, and ⌘E's
    /// fields if the last panel was left expanded (#286).
    init(
        actions: CaptureModel.Actions, directory: @escaping () -> PlaceDirectory,
        lastArea: @escaping () -> TaskArea, isExpanded: @escaping () -> Bool
    ) {
        panel = CapturePanelController(actions: actions)
        (self.directory, self.lastArea, self.isExpanded) = (directory, lastArea, isExpanded)
    }

    /// Registers the hotkey on sign-in; unregisters it and closes any open panel on sign-out.
    func setEnabled(_ isEnabled: Bool) {
        guard isEnabled else { return disable() }
        guard hotKey == nil else { return }
        // From another app there is no window to seed from: the last kind, ⏎ Today.
        hotKey = GlobalHotKey.capture { [weak self] in self?.show(context: CaptureContext()) }
    }

    /// Opens the panel seeded with `context` (spec §4's table).
    func show(context: CaptureContext) {
        panel.show(context: context, directory: directory(), lastArea: lastArea(), isExpanded: isExpanded())
    }

    private func disable() {
        hotKey?.unregister()
        hotKey = nil
        panel.close()
    }
}
