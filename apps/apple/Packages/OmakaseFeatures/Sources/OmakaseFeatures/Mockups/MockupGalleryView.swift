import SwiftUI

/// Every M2 mockup by name, so the design record's screenshots can be
/// rendered outside Xcode's canvas (#101).
///
///     for page in MockupGallery.pages { NSHostingView(rootView: page.view(.dark)) }
public enum MockupGallery {
    public struct Page: Sendable {
        public let name: String
        /// Whether the page is a whole window (title bar and sidebar) rather than a floating surface.
        public let isWindow: Bool
        private let make: @MainActor @Sendable (ColorScheme) -> AnyView

        init(_ name: String, isWindow: Bool = false, _ make: @escaping @MainActor @Sendable (ColorScheme) -> AnyView) {
            self.name = name
            self.isWindow = isWindow
            self.make = make
        }

        @MainActor public func view(_ scheme: ColorScheme) -> AnyView { make(scheme) }
    }

    public static let pages: [Page] = [
        Page("shell-plan", isWindow: true) {
            AnyView(ShellMockupView(selection: .plan).frame(width: 1300, height: 760).preferredColorScheme($0))
        },
        Page("focus-kanban", isWindow: true) {
            AnyView(ShellMockupView(selection: .focus).frame(width: 1300, height: 760).preferredColorScheme($0))
        },
        Page("plan") { AnyView(PlanMockupView().frame(width: 1120, height: 680).preferredColorScheme($0)) },
        Page("focus-list") {
            AnyView(FocusMockupView(layout: .list).frame(width: 1120, height: 720).preferredColorScheme($0))
        },
        Page("timer") { AnyView(TimerPhasesView().mockupCanvas($0)) },
        Page("menubar") { AnyView(MenuBarPanelView().mockupCanvas($0)) },
        Page("capture") { AnyView(CaptureOverDesktopView().preferredColorScheme($0)) },
        Page("signin") { AnyView(SignInMockupView().preferredColorScheme($0)) },
    ]
}
