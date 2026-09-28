import SwiftUI

/// The menu-bar extra's label (spec, Menu bar): the countdown beside the
/// timer glyph while a phase is on, the glyph alone when idle.
///
/// A view of its own so that only this body reads `timer.now`. The
/// `MenuBarExtra` label builder runs inside `App.body`, so reading the
/// countdown there made `App.body` observe the per-second tick. Each tick
/// then rebuilt `MainWindowView` with fresh closures SwiftUI can't compare,
/// and the whole window, sidebar included, re-ran its body every second
/// (#260 review).
///
///     MenuBarExtra { … } label: { MenuBarTimerLabelView(timer: timer) }
public struct MenuBarTimerLabelView: View {
    private let timer: TimerModel

    public init(timer: TimerModel) { self.timer = timer }

    public var body: some View {
        if let text = MenuBar.label(for: timer.state, remaining: timer.remainingText) {
            Label(text, systemImage: "timer")
        } else {
            Image(systemName: "timer")
        }
    }
}
