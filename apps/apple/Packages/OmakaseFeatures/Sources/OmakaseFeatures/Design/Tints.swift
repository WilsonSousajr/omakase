/// A pomodoro phase. Each tints the timer's glass so the state reads at a
/// glance, in the window and in the menu bar (IDEA.md, Focus Mode).
///
///     TimerGlass().tint(TimerPhase.focus.tint.color)
public enum TimerPhase: String, CaseIterable, Sendable {
    case focus
    case shortBreak
    case longBreak

    public var tint: DesignColor {
        switch self {
        case .focus: Palette.shu
        case .shortBreak: Palette.matcha
        case .longBreak: Palette.indigo
        }
    }
}

/// The colour of a task's leading priority mark. Priority is a mark, never a
/// row fill, so a list of urgent tasks does not turn the window red.
///
///     Capsule().fill(PriorityMark.color(for: row.priority).color)
public enum PriorityMark {
    public static let low = DesignColor(both: 0x6B7280)
    public static let medium = DesignColor(both: 0xF59E0B)
    public static let high = DesignColor(both: 0xF97316)
    public static let urgent = DesignColor(both: 0xEF4444)

    private static let byName = ["low": low, "medium": medium, "high": high, "urgent": urgent]

    /// A priority the cache has never seen gets the neutral mark.
    public static func color(for priority: String) -> DesignColor {
        byName[priority] ?? Palette.inkMuted
    }
}
