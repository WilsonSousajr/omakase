import OmakaseStore
import SwiftData
import SwiftUI

/// Review: the day's close as one scrolling column, not a wizard (M3.4
/// spec, Decisions): the summary, where each open task goes, how it went,
/// then Shut down. A closed day shows its calm state and Reopen instead.
/// Reads the store; the draft saves through `ReviewModel`'s injected writes,
/// so it queues offline.
public struct ReviewView: View {
    private let model: ReviewModel
    @Query private var records: [TaskRecord]
    @Query private var reviews: [DailyReviewRecord]
    private let day: String

    public init(day: String, model: ReviewModel) {
        (self.day, self.model) = (day, model)
        let target: String? = day
        _records = Query(filter: #Predicate<TaskRecord> { $0.scheduledDay == target || $0.isCarriedOver })
        _reviews = Query(filter: #Predicate<DailyReviewRecord> { $0.day == day })
    }

    public var body: some View {
        let summary = ReviewSummary(records: records, day: day)
        VStack(alignment: .leading, spacing: 0) {
            ReviewHeaderView(day: day)
            Divider().overlay(Palette.hairline.color)
            ScrollView { column(summary) }
        }
        .onChange(of: ReviewValues(record: reviews.first), initial: true) { _, values in
            model.load(day: day, values: values)
        }
        .onDisappear { model.flush() }
        .navigationTitle("Review")
    }

    private func column(_ summary: ReviewSummary) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xLarge) {
            if model.isShutdown { ReviewClosedView(model: model) }
            ReviewSummaryCardView(summary: summary)
            if !model.isShutdown && !summary.unfinished.isEmpty {
                ReviewRolloverView(cards: summary.unfinished, model: model)
            }
            ReviewReflectionView(model: model)
            if !model.isShutdown { ReviewShutdownView(model: model, unfinished: summary.unfinished.map(\.id)) }
        }
        .padding(Spacing.large)
        .frame(maxWidth: 640, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The day, as Focus's header shows it.
struct ReviewHeaderView: View {
    let day: String

    var body: some View {
        HStack {
            Text(day).sectionLabel()
            Spacer()
        }
        .padding(Spacing.large)
    }
}

/// Today: done of planned, and the estimate of what got done.
struct ReviewSummaryCardView: View {
    let summary: ReviewSummary

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("Today").sectionLabel()
            Text(summary.doneLabel)
                .font(TypeScale.title).monospacedDigit().foregroundStyle(Palette.ink.color)
            if let estimate = summary.estimateLabel {
                Text(estimate).font(TypeScale.caption).monospacedDigit().foregroundStyle(Palette.inkMuted.color)
            }
        }
        .reviewCard()
    }
}

extension View {
    /// What the review's sections sit on: the opaque `surface`, as cards do.
    func reviewCard() -> some View {
        padding(Spacing.large)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface.color, in: .rect(cornerRadius: Radius.medium))
    }
}
