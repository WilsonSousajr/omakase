import OmakaseStore

/// What a kind chip wears (glass-pass §1, #283): colour as a mark, never a
/// fill. Every chip is a grey glass capsule; only the chosen one shows its
/// kind, as a dot before its label.
///
///     KindChip.dot(for: .study, selection: .study)   // KindTint.study
enum KindChip {
    /// The chosen chip's kind colour; nil for every other chip.
    static func dot(for area: TaskArea, selection: TaskArea) -> DesignColor? {
        area == selection ? KindTint.token(for: area) : nil
    }
}
