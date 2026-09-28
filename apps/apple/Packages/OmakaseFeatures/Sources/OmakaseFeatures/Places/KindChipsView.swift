import OmakaseStore
import SwiftUI

/// The three kind chips (spec §4): Work, Study and Life, each its glyph and
/// name on a grey glass capsule, the chosen one with a faint ink fill and a
/// dot in its kind colour (glass-pass §1, #283: colour as a mark, not a
/// border). The capture panel shows them and the task editor reuses them
/// (S5). ⌘1–3 belong to the panel's hidden buttons, not to the chips, so
/// Tab stays in the field.
///
///     KindChipsView(selection: Binding(get: { model.area }, set: { model.choose($0) }))
public struct KindChipsView: View {
    @Binding private var selection: TaskArea

    public init(selection: Binding<TaskArea>) { _selection = selection }

    public var body: some View {
        HStack(spacing: Spacing.small) {
            ForEach(TaskArea.allCases, id: \.self) { area in chip(for: area) }
        }
        .motion(Motion.select, value: selection)
        // Never squeezed by a long parent title beside it (#264's review).
        .fixedSize()
    }

    private func chip(for area: TaskArea) -> some View {
        let isSelected = area == selection
        return Button {
            selection = area
        } label: {
            HStack(spacing: Spacing.tiny) {
                if let dot = KindChip.dot(for: area, selection: selection) {
                    Circle().fill(dot.color).frame(width: ControlMetrics.markDot, height: ControlMetrics.markDot)
                }
                Label(area.title, systemImage: area.symbol)
            }
        }
        .buttonStyle(SecondaryButtonStyle(isSelected: isSelected))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .help("\(area.title) (⌘\(area.shortcutDigit))")
    }
}

#Preview("Kind chips") {
    @Previewable @State var area = TaskArea.study
    KindChipsView(selection: $area).padding(Spacing.large)
}
