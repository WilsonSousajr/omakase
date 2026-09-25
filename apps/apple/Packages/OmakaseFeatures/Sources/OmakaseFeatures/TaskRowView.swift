import SwiftUI

/// One task in a list: a leading priority mark, a checkbox and the title.
/// Priority is a mark, never a row fill (docs/design-system-apple.md).
///
///     TaskRowView(title: "Write the essay", priority: "high", isCompleted: false) { … }
public struct TaskRowView: View {
    private let title: String
    private let priority: String
    private let isCompleted: Bool
    private let toggle: () -> Void

    public init(title: String, priority: String, isCompleted: Bool, toggle: @escaping () -> Void = {}) {
        self.title = title
        self.priority = priority
        self.isCompleted = isCompleted
        self.toggle = toggle
    }

    public var body: some View {
        HStack(spacing: Spacing.small) {
            Capsule()
                .fill(PriorityMark.color(for: priority).color.opacity(isCompleted ? 0.35 : 1))
                .frame(width: 3, height: 16)
            Toggle(isOn: Binding(get: { isCompleted }, set: { _ in toggle() })) {
                Text(title)
                    .font(TypeScale.body)
                    .strikethrough(isCompleted)
                    .foregroundStyle((isCompleted ? Palette.inkMuted : Palette.ink).color)
            }
            .toggleStyle(.checkbox)
        }
        .padding(.vertical, Spacing.tiny)
    }
}
