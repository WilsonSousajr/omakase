import SwiftUI

/// A click selects; a second click asks to edit (#217). The double-click
/// runs beside the single click instead of waiting for it to fail, so a
/// selection isn't delayed. Neither takes a drag: `.draggable` starts on
/// movement, which a tap never recognises, as on Focus's Kanban cards.
extension View {
    func planSelectable(select: @escaping () -> Void, edit: @escaping () -> Void) -> some View {
        contentShape(.rect)
            .onTapGesture(perform: select)
            .simultaneousGesture(TapGesture(count: 2).onEnded(edit))
    }
}

/// The Kanban card's selection: a 2-pt accent border, never shu.
struct PlanSelectionBorderView: View {
    let isSelected: Bool
    let radius: CGFloat

    var body: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: radius)
                .strokeBorder(Palette.accent.color, lineWidth: 2)
                .allowsHitTesting(false)
        }
    }
}
