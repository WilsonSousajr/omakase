import SwiftUI

/// The day as a list: Carried over, In progress, To do, Done. Each row's
/// checkbox completes the task, offline too.
struct FocusBoardListView: View {
    let board: FocusBoard
    let day: String
    let model: FocusModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xLarge) {
                section("Carried over", board.carriedOver)
                section("In progress", board.inProgress)
                section("To do", board.toDo)
                section("Done", board.done)
            }
            .padding(Spacing.xLarge)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private func section(_ title: String, _ cards: [FocusCard]) -> some View {
        if !cards.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.small) {
                Text(title).sectionLabel()
                ForEach(cards) { card in
                    TaskRowView(
                        title: card.title, priority: card.priority, isCompleted: card.isCompleted,
                        marks: FocusMarks.labels(for: card, day: day, calendar: model.calendar)
                    ) { model.toggle(card.id) }
                    .contextMenu { FocusTaskMenuView(card: card, day: day, model: model) }
                    .padding(.horizontal, Spacing.small)
                    .background(
                        (model.selectedID == card.id ? Palette.surface.color : .clear),
                        in: .rect(cornerRadius: Radius.small)
                    )
                    .contentShape(.rect)
                    .onTapGesture { model.selectedID = card.id }
                }
            }
        }
    }
}
