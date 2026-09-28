import OmakaseStore

/// How a kind reads on screen: its name, glyph and the digit ⌘1–3 picks it
/// with in capture (spec §2, §4).
extension TaskArea {
    public var title: String {
        switch self {
        case .work: "Work"
        case .study: "Study"
        case .life: "Life"
        }
    }

    public var symbol: String {
        switch self {
        case .work: "briefcase"
        case .study: "graduationcap"
        case .life: "leaf"
        }
    }

    /// The digit ⌘1–3 picks this kind with, in capture (spec §4).
    public var shortcutDigit: Int {
        switch self {
        case .work: 1
        case .study: 2
        case .life: 3
        }
    }

    /// `ParentMenuChip`'s label with no parent chosen (spec §4, S5 #258):
    /// which kind of parent is missing. Life never shows the chip.
    public var noParentTitle: String {
        self == .study ? "No discipline" : "No project"
    }
}
