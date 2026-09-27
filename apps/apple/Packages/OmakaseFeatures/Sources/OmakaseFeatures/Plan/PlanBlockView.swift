import SwiftUI

/// A planned block you can act on (#203): drag it to move it, by time or
/// day; drag its bottom edge to resize it in 15-minute steps, previewed
/// live; delete it from its menu. A click selects it and a double-click
/// opens its task in the editor (#217, #218); the resize handle is an
/// overlay above the tap, so it keeps its own drag.
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
            .overlay { PlanSelectionBorderView(isSelected: model.selection == .block(item.id), radius: Radius.small) }
            .planSelectable(select: { model.select(.block(item.id)) }, edit: { editTask() })
            .draggable(PlanDragPayload.block(item.id).text)
            .contextMenu { menu }
            .overlay(alignment: .bottom) { handle }
    }

    @ViewBuilder private var menu: some View {
        if item.taskID != nil {
            Button("Open task", systemImage: "doc.text") { model.openTask(of: item) }
            Button("Edit task…", systemImage: "pencil") { editTask() }
        }
        Button("Delete block", systemImage: "trash", role: .destructive) { model.deleteBlock(item.id) }
    }

    /// A study block's parent is not a task, so it has nothing to edit.
    private func editTask() {
        guard let taskID = item.taskID else { return }
        model.beginEditing(taskID)
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
            tint: item.tint, taskID: item.taskID)
    }
}
