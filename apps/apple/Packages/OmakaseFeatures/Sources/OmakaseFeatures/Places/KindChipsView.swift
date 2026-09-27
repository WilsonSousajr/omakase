import OmakaseStore
import SwiftUI

/// The three kind chips (spec §4): Work, Study and Life, each its glyph and
/// name, the chosen one filled and outlined in its kind colour. The capture
/// panel shows them and the task editor reuses them (S5). ⌘1–3 belong to
/// the panel's hidden buttons, not to the chips, so Tab stays in the field.
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
    }

    private func chip(for area: TaskArea) -> some View {
        let isSelected = area == selection
        let tint = KindTint.token(for: area).color
        return Button {
            selection = area
        } label: {
            Label(area.title, systemImage: area.symbol)
                .font(TypeScale.body)
                .foregroundStyle(isSelected ? tint : Palette.inkMuted.color)
                .padding(.horizontal, Spacing.medium)
                .padding(.vertical, Spacing.tiny)
                .background(isSelected ? tint.opacity(0.14) : .clear, in: .capsule)
                .overlay { Capsule().strokeBorder(isSelected ? tint : Palette.hairline.color) }
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .help("\(area.title) (⌘\(area.shortcutDigit))")
    }
}

#Preview("Kind chips") {
    @Previewable @State var area = TaskArea.study
    KindChipsView(selection: $area).padding(Spacing.large)
}
