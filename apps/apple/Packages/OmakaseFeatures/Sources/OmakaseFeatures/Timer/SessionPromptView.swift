import SwiftUI

/// The end-of-focus sheet: an optional rating and what was accomplished,
/// saved to the task's block. Escape or Skip dismisses without writing.
public struct SessionPromptView: View {
    private let prompt: SessionPrompt
    private let submit: ([SessionPrompt.Write]) -> Void
    @State private var rating: Int?
    @State private var notes: String
    @Environment(\.dismiss) private var dismiss

    public init(prompt: SessionPrompt, submit: @escaping ([SessionPrompt.Write]) -> Void) {
        (self.prompt, self.submit) = (prompt, submit)
        _notes = State(initialValue: prompt.prefill)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            Text("Focus done").sectionLabel()
            Text(prompt.taskTitle).font(TypeScale.title).foregroundStyle(Palette.ink.color)
            SessionRatingView(rating: $rating)
            Text("What did you accomplish?").sectionLabel()
            TextEditor(text: $notes)
                .font(TypeScale.body)
                .scrollContentBackground(.hidden)
                .padding(Spacing.small)
                .frame(height: 110)
                .background(Palette.surface.color, in: .rect(cornerRadius: Radius.medium))
            HStack {
                Spacer()
                Button("Skip") { dismiss() }.buttonStyle(.glass).keyboardShortcut(.cancelAction)
                Button("Save") {
                    submit(prompt.writes(rating: rating, notes: notes))
                    dismiss()
                }
                .buttonStyle(.primary)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Spacing.xLarge)
        .frame(width: 420)
    }
}

/// Five dots, 1-5; clicking the chosen one again clears it.
struct SessionRatingView: View {
    @Binding var rating: Int?

    var body: some View {
        HStack(spacing: Spacing.small) {
            ForEach(1...5, id: \.self) { value in
                Button {
                    rating = rating == value ? nil : value
                } label: {
                    Image(systemName: value <= (rating ?? 0) ? "circle.fill" : "circle")
                        .foregroundStyle((value <= (rating ?? 0) ? Palette.ink : Palette.inkMuted).color)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Rate \(value) of 5")
            }
        }
    }
}
