import AppKit
import OmakaseFeatures
import SwiftUI

/// Opens and closes the capture panel (M3.5 spec, Decisions). Each opening
/// is a new panel over a new `CaptureModel`: the panel is closed, never
/// hidden, so there is no stale draft. Closing gives focus back to the app
/// that had it when the panel opened.
///
///     let panel = CapturePanelController { title, destination in services.capture(title, to: destination) }
///     panel.show()
@MainActor
final class CapturePanelController {
    private let onCapture: (String, CaptureDestination) -> Void
    private var panel: CapturePanel?
    private var previousApp: NSRunningApplication?

    init(onCapture: @escaping (String, CaptureDestination) -> Void) { self.onCapture = onCapture }

    func show() {
        if let panel {
            panel.makeKeyAndOrderFront(nil)
            return
        }
        let onCapture = self.onCapture
        let model = CaptureModel(actions: .init(capture: { onCapture($0, $1) }))
        let content = CaptureView(model: model, onClose: { [weak self] in self?.close() })
        // The hosting view is its own root, so the window's .tint never reaches it (#214).
        let panel = CapturePanel(content: content.tint(AppTint.capturePanel.color))
        panel.center(onTopThirdOf: NSScreen.withMouse ?? NSScreen.main)
        previousApp = NSWorkspace.shared.frontmostApplication
        self.panel = panel
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
    }

    func close() {
        guard let panel else { return }
        panel.close()
        self.panel = nil
        guard let previousApp, previousApp != NSRunningApplication.current else { return }
        previousApp.activate()
    }
}

/// A floating, borderless-looking panel that can take the keyboard: the
/// SwiftUI glass card is its whole content.
private final class CapturePanel: NSPanel {
    init(content: some View) {
        super.init(
            contentRect: .zero, styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered, defer: false)
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        for kind in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            standardWindowButton(kind)?.isHidden = true
        }
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        (isOpaque, backgroundColor, hasShadow) = (false, .clear, false)
        (isReleasedWhenClosed, hidesOnDeactivate, isMovableByWindowBackground) = (false, false, true)
        let hosting = NSHostingView(rootView: content)
        contentView = hosting
        setContentSize(hosting.fittingSize)
    }

    override var canBecomeKey: Bool { true }

    /// Centred across, a third of the way down: where the eye already is.
    func center(onTopThirdOf screen: NSScreen?) {
        guard let visible = screen?.visibleFrame else { return center() }
        let origin = NSPoint(
            x: visible.midX - frame.width / 2, y: visible.maxY - visible.height / 3 - frame.height / 2)
        setFrameOrigin(origin)
    }
}

extension NSScreen {
    /// The screen the pointer is on: the active one, for a hotkey pressed over another app.
    fileprivate static var withMouse: NSScreen? {
        screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }
    }
}
