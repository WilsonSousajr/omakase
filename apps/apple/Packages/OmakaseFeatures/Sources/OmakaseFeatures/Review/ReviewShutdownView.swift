import SwiftUI

/// The tasks still open, carried-over first, each with where it goes when
/// the day shuts down: tomorrow unless changed (IDEA §8.2, step 2).
struct ReviewRolloverView: View {
    let cards: [FocusCard]
    let model: ReviewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("Unfinished").sectionLabel()
            ForEach(cards) { card in ReviewRolloverRowView(card: card, model: model) }
        }
        .reviewCard()
    }
}

/// One open task and its rollover menu, styled as Focus's Reschedule menu.
struct ReviewRolloverRowView: View {
    let card: FocusCard
    let model: ReviewModel
    @Environment(\.calendar) private var calendar
    @State private var picking = false
    @State private var picked = Date.now

    var body: some View {
        HStack(spacing: Spacing.small) {
            Text(card.title).font(TypeScale.body).foregroundStyle(Palette.ink.color).lineLimit(1)
            Spacer(minLength: Spacing.small)
            if let carried = card.carriedFromLabel(calendar: calendar) {
                Text(carried).font(TypeScale.caption).foregroundStyle(Palette.inkMuted.color)
            }
            if PriorityMark.showsInRow(card.priority) { PriorityBadgeView(priority: card.priority) }
            menu
        }
        .padding(.vertical, Spacing.tiny)
    }

    private var menu: some View {
        Menu {
            Button("Tomorrow") { model.chooseRollover(.tomorrow, for: card.id) }
            Button("Pick a date…") { picking = true }
            Button("Backlog") { model.chooseRollover(.backlog, for: card.id) }
        } label: {
            // An explicit ink label: a `.menuStyle(.button)` menu draws its own dim (#172).
            Text(model.rolloverLabel(for: card.id)).foregroundStyle(FocusPanelActionsView.menuLabel.color)
        }
        .menuStyle(.secondary)
        .fixedSize()
        .popover(isPresented: $picking) { datePicker }
    }

    private var datePicker: some View {
        VStack(spacing: Spacing.medium) {
            DatePicker("Move to", selection: $picked, displayedComponents: .date).datePickerStyle(.graphical)
            Button("Choose") {
                model.chooseRollover(.date(picked), for: card.id)
                picking = false
            }
            .buttonStyle(.primary)
        }
        .padding(Spacing.large)
    }
}

/// Shut down, the screen's one primary action, and what it is about to do.
struct ReviewShutdownView: View {
    let model: ReviewModel
    let unfinished: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Button("Shut down") { model.shutDown(unfinished: unfinished) }
                .buttonStyle(.primary)
            Text(ReviewModel.shutDownHint(moving: unfinished.count))
                .font(TypeScale.caption).foregroundStyle(Palette.inkMuted.color)
        }
    }
}

/// The closed day (IDEA §8.2, step 6): calm, with Reopen for a late change.
struct ReviewClosedView: View {
    let model: ReviewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            Label("Day closed", systemImage: "moon.stars")
                .font(TypeScale.title).foregroundStyle(Palette.ink.color)
            Text(ReviewModel.shutdownLine).font(TypeScale.body).foregroundStyle(Palette.inkMuted.color)
            Button("Reopen") { model.reopen() }
                .buttonStyle(.secondary)
        }
        .reviewCard()
    }
}
