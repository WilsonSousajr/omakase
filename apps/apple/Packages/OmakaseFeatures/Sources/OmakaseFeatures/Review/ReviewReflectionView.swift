import SwiftUI

/// How did it go: the rating, the energy (#130) and the win of the day
/// (IDEA §8.2). Every field is optional, and each change saves on its own.
struct ReviewReflectionView: View {
    let model: ReviewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            Text("How did it go").sectionLabel()
            ReviewRatingView(model: model)
            ReviewEnergyView(model: model)
            ReviewWinView(model: model)
        }
        .reviewCard()
    }
}

/// "How productive did you feel today?": five marks, filled up to the rating.
/// Choosing the chosen mark again clears it.
struct ReviewRatingView: View {
    /// An empty mark's colour, beside the filled ones.
    static let emptyMark = Palette.inkMuted
    let model: ReviewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("How productive did you feel?").font(TypeScale.body).foregroundStyle(Palette.ink.color)
            HStack(spacing: Spacing.small) {
                ForEach(ReviewModel.ratings, id: \.self) { mark in
                    Button {
                        model.chooseRating(mark)
                    } label: {
                        dot(filled: mark <= (model.draft.rating ?? 0))
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Rate \(mark) of \(ReviewModel.ratings.upperBound)")
                }
            }
        }
    }

    private func dot(filled: Bool) -> some View {
        Image(systemName: filled ? "circle.fill" : "circle")
            .foregroundStyle((filled ? Palette.ink : Self.emptyMark).color)
    }
}

/// How much energy the day left: Low, Steady or High, one at most.
struct ReviewEnergyView: View {
    /// An unchosen level's label colour, beside the chosen one.
    static let unchosenLabel = Palette.inkMuted
    let model: ReviewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("Energy").font(TypeScale.body).foregroundStyle(Palette.ink.color)
            HStack(spacing: Spacing.small) {
                ForEach(ReviewEnergy.allCases) { level in
                    Button {
                        model.chooseEnergy(level.rawValue)
                    } label: {
                        label(level)
                    }
                    .buttonStyle(.glass)
                }
            }
        }
    }

    private func label(_ level: ReviewEnergy) -> some View {
        let chosen = model.draft.energy == level.rawValue
        return Label(level.title, systemImage: chosen ? "checkmark.circle.fill" : "circle")
            .foregroundStyle((chosen ? Palette.ink : Self.unchosenLabel).color)
    }
}

/// "What was your biggest win today?": free text, saved as it is typed.
struct ReviewWinView: View {
    let model: ReviewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("Win of the day").font(TypeScale.body).foregroundStyle(Palette.ink.color)
            // An explicit closure, not `set: model.setWin`: partially applying the
            // main-actor method crashes Swift 6.2's IRGen (Xcode 26.6, CI).
            TextField(
                "What was your biggest win today?",
                text: Binding(get: { model.draft.win }, set: { model.setWin($0) }),
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .font(TypeScale.body)
            .foregroundStyle(Palette.ink.color)
            .lineLimit(2...6)
            .padding(Spacing.small)
            .background(Palette.background.color, in: .rect(cornerRadius: Radius.small))
        }
    }
}
