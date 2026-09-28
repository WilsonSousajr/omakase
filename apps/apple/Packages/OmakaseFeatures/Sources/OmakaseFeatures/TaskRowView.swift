import OmakaseStore
import SwiftUI

/// One task in a list: a checkbox, its kind mark, the title, and trailing
/// its estimate and priority badge, as the web client drew them (kind mark
/// added spec §8).
///
///     TaskRowView(title: "Write the essay", priority: "high", minutes: 45, isCompleted: false, filing: filing) { … }
public struct TaskRowView: View {
    private let title: String
    private let priority: String
    private let minutes: Int
    private let isCompleted: Bool
    private let marks: [String]
    private let hasReminder: Bool
    private let isRepeating: Bool
    private let filing: TaskFiling
    private let showsKindMark: Bool
    private let toggle: () -> Void
    @Environment(\.placeDirectory) private var directory

    public init(
        title: String, priority: String, minutes: Int = 0, isCompleted: Bool, marks: [String] = [],
        hasReminder: Bool = false, isRepeating: Bool = false, filing: TaskFiling = TaskFiling(area: .work, parent: nil),
        showsKindMark: Bool = true, toggle: @escaping () -> Void = {}
    ) {
        self.title = title
        self.priority = priority
        self.minutes = minutes
        self.isCompleted = isCompleted
        // Marks, when given, already carry the estimate (FocusMarks).
        self.marks = marks.isEmpty && minutes > 0 ? ["\(minutes)m"] : marks
        (self.hasReminder, self.isRepeating) = (hasReminder, isRepeating)
        (self.filing, self.showsKindMark) = (filing, showsKindMark)
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
            // Hidden on a place's own list (S6), which would only repeat the title.
            if showsKindMark { KindMarkView(mark: directory.mark(for: filing)) }
            Spacer(minLength: Spacing.small)
            if !marks.isEmpty {
                Text(marks.joined(separator: " · "))
                    .font(TypeScale.caption).monospacedDigit().foregroundStyle(Palette.inkMuted.color)
            }
            if isRepeating { RepeatGlyphView() }
            if hasReminder { ReminderBellView() }
            if PriorityMark.showsInRow(priority) {
                PriorityBadgeView(priority: priority).opacity(isCompleted ? 0.5 : 1)
            }
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

/// The small mark on a task with a reminder set (#187).
struct ReminderBellView: View {
    var body: some View {
        Image(systemName: "bell.fill")
            .font(TypeScale.caption)
            .foregroundStyle(Palette.inkMuted.color)
            .accessibilityLabel("Reminder set")
    }
}

/// The small mark on a task in a repeating series (#206).
struct RepeatGlyphView: View {
    var body: some View {
        Image(systemName: "repeat")
            .font(TypeScale.caption)
            .foregroundStyle(Palette.inkMuted.color)
            .accessibilityLabel("Repeats")
    }
}
