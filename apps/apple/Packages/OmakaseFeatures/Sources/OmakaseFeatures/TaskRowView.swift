import SwiftUI

/// One task in a list: a checkbox, the title, and trailing its estimate and
/// priority badge, as the web client drew them.
///
///     TaskRowView(title: "Write the essay", priority: "high", minutes: 45, isCompleted: false) { … }
public struct TaskRowView: View {
    private let title: String
    private let priority: String
    private let minutes: Int
    private let isCompleted: Bool
    private let toggle: () -> Void

    public init(
        title: String, priority: String, minutes: Int = 0, isCompleted: Bool, toggle: @escaping () -> Void = {}
    ) {
        self.title = title
        self.priority = priority
        self.minutes = minutes
        self.isCompleted = isCompleted
        self.toggle = toggle
    }

    public var body: some View {
        HStack(spacing: Spacing.small) {
            Toggle(isOn: Binding(get: { isCompleted }, set: { _ in toggle() })) {
                Text(title)
                    .font(TypeScale.body)
                    .strikethrough(isCompleted)
                    .foregroundStyle((isCompleted ? Palette.inkMuted : Palette.ink).color)
                    .lineLimit(1)
            }
            .toggleStyle(.checkbox)
            Spacer(minLength: Spacing.small)
            if minutes > 0 {
                Text("\(minutes)m").font(TypeScale.caption).monospacedDigit().foregroundStyle(Palette.inkMuted.color)
            }
            if !priority.isEmpty { PriorityBadgeView(priority: priority).opacity(isCompleted ? 0.5 : 1) }
        }
        .padding(.vertical, Spacing.tiny)
    }
}

/// The web client's priority pill: a tinted capsule with a dot and the name.
/// The name stays in ink, because amber on paper is too faint to read.
public struct PriorityBadgeView: View {
    private let priority: String

    public init(priority: String) { self.priority = priority }

    public var body: some View {
        let tint = PriorityMark.color(for: priority).color
        HStack(spacing: Spacing.tiny) {
            Circle().fill(tint).frame(width: 6, height: 6)
            Text(priority.capitalized).font(TypeScale.caption).foregroundStyle(Palette.ink.color)
        }
        .padding(.horizontal, Spacing.small)
        .padding(.vertical, 2)
        .background(tint.opacity(0.14), in: .capsule)
    }
}
