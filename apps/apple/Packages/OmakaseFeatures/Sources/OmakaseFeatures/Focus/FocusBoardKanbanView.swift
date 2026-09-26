import SwiftUI

/// The board: To do (carried-over first), In progress, Done. Dragging a card
/// to another column moves it there, offline too; Done completes it.
struct FocusBoardKanbanView: View {
    let board: FocusBoard
    let day: String
    let model: FocusModel

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.medium) {
            ForEach(board.columns) { column in
                FocusBoardColumnView(column: column, day: day, model: model)
            }
        }
        .padding(Spacing.large)
    }
}

struct FocusBoardColumnView: View {
    let column: FocusBoard.Column
    let day: String
    let model: FocusModel
    @State private var isTargeted = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.small) {
                Text("\(column.title) · \(column.cards.count)").sectionLabel()
                ForEach(column.cards) { card in
                    FocusBoardCardView(
                        card: card, marks: FocusMarks.labels(for: card, day: day, calendar: model.calendar),
                        isSelected: model.selectedID == card.id
                    )
                    .onTapGesture { model.selectedID = card.id }
                    .draggable(card.id)
                    .contextMenu { FocusTaskMenuView(card: card, day: day, model: model) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.medium)
        }
        .background(Palette.surface.color.opacity(isTargeted ? 0.7 : 0.35), in: .rect(cornerRadius: Radius.large))
        .dropDestination(for: String.self) { ids, _ in
            for id in ids { model.move(id, to: column.status) }
            return !ids.isEmpty
        } isTargeted: {
            isTargeted = $0
        }
    }
}

/// A Kanban card: the title, then its priority pill and marks.
struct FocusBoardCardView: View {
    let card: FocusCard
    let marks: [String]
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text(card.title)
                .font(TypeScale.body)
                .strikethrough(card.isCompleted)
                .foregroundStyle((card.isCompleted ? Palette.inkMuted : Palette.ink).color)
            HStack(spacing: Spacing.small) {
                PriorityBadgeView(priority: card.priority)
                if !marks.isEmpty {
                    Text(marks.joined(separator: " · "))
                        .font(TypeScale.caption).foregroundStyle(Palette.inkMuted.color)
                }
            }
        }
        .padding(Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface.color, in: .rect(cornerRadius: Radius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.medium)
                .strokeBorder((isSelected ? Palette.accent : Palette.hairline).color, lineWidth: isSelected ? 2 : 1)
        )
        .contentShape(.rect(cornerRadius: Radius.medium))
    }
}
