import OmakaseStore

/// What the capture panel opens with (spec §4): a filing to start from (nil
/// means the remembered kind), the day ⏎ saves to (nil means Today) and a
/// drawn slot on Plan (S11, #264), which wins over the day.
///
///     CaptureContext.forSelection(.item(.plan), planDay: "2026-09-28")   // ⏎ saves to Mon 28
public struct CaptureContext: Equatable, Sendable {
    public var filing: TaskFiling?
    public var day: String?
    public var slot: PlanPlacement?

    public init(filing: TaskFiling? = nil, day: String? = nil, slot: PlanPlacement? = nil) {
        (self.filing, self.day, self.slot) = (filing, day, slot)
    }

    /// File › New Task's context: the focused window's, or the default when
    /// no window is focused, so ⌘N is never disabled for want of one.
    public static func forCommand(focused: CaptureContext?) -> CaptureContext {
        focused ?? CaptureContext()
    }

    /// The context of the screen the sidebar shows (spec §4's table): Plan
    /// seeds the day it shows, a place seeds its filing, and every other
    /// screen seeds nothing (the last kind, ⏎ Today).
    public static func forSelection(_ selection: SidebarSelection, planDay: String?) -> CaptureContext {
        switch selection {
        case .item(.plan): CaptureContext(day: planDay)
        case .item: CaptureContext()
        case .place(let place): CaptureContext(filing: place.filing)
        }
    }
}
