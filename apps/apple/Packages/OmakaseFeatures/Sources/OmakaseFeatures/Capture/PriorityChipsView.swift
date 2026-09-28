import SwiftUI

/// The four priorities as grey chips (glass-pass §1, #283): the chosen one
/// has a faint ink fill and a dot in its priority mark's colour, as the
/// kind chips do. The capture panel's ⌘E fields show them (#286).
///
///     PriorityChipsView(selection: Binding(get: { model.shownPriority }, set: { model.choose(priority: $0) }))
struct PriorityChipsView: View {
    @Binding var selection: String

    var body: some View {
        HStack(spacing: Spacing.small) {
            ForEach(TaskDraft.priorities, id: \.self) { name in chip(for: name) }
        }
        .motion(Motion.select, value: selection)
    }

    private func chip(for name: String) -> some View {
        let isSelected = name == selection
        return Button {
            selection = name
        } label: {
            HStack(spacing: Spacing.tiny) {
                if isSelected {
                    Circle().fill(PriorityMark.color(for: name).color)
                        .frame(width: ControlMetrics.markDot, height: ControlMetrics.markDot)
                }
                Text(name.capitalized)
            }
        }
        .buttonStyle(SecondaryButtonStyle(isSelected: isSelected))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview("Priority chips") {
    @Previewable @State var priority = "high"
    PriorityChipsView(selection: $priority).padding(Spacing.large)
}
