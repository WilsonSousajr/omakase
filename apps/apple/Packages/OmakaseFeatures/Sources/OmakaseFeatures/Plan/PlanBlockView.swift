import SwiftUI

/// A planned block you can act on (#203): drag it to move it, by time or
/// day; drag its bottom edge to resize it in 15-minute steps, previewed
/// live; delete it from its menu.
struct PlanBlockView: View {
    /// Thin enough to leave the block's body for moving.
    static let handleHeight: CGFloat = 6

    let item: CalendarItem
    let model: PlanModel
    let items: [CalendarItem]
    let layout: CalendarLayout
    @Binding var resizing: CalendarItem?

    var body: some View {
        CalendarItemView(item: item)
            .draggable(PlanDragPayload.block(item.id).text)
            .contextMenu {
                Button("Delete block", systemImage: "trash", role: .destructive) { model.deleteBlock(item.id) }
            }
            .overlay(alignment: .bottom) { handle }
    }

    private var handle: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: Self.handleHeight)
            .contentShape(.rect)
            .pointerStyle(.frameResize(position: .bottom))
            .gesture(resize)
            .accessibilityLabel("Resize \(item.title)")
    }

    private var resize: some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named(CalendarDayColumnView.space))
            .onChanged { drag in resizing = preview(bottom: drag.location.y) }
            .onEnded { drag in
                resizing = nil
                model.resize(item, bottom: drag.location.y, items: items)
            }
    }

    /// The block as it would be with its bottom at `bottom`, the same snapping as the write.
    private func preview(bottom: CGFloat) -> CalendarItem? {
        guard let placement = PlanDrop.resize(item, bottom: bottom, layout: layout) else { return nil }
        return CalendarItem(
            id: item.id, day: item.day, start: item.start, end: placement.end, title: item.title, kind: item.kind,
            tint: item.tint)
    }
}
