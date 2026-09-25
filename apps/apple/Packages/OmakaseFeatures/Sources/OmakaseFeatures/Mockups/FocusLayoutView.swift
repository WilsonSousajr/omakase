import SwiftUI

/// M2 mockup: Focus (IDEA.md, Focus Mode). The day on the left, the current
/// block in the middle, the timer and session notes on the right. Content is
/// opaque on paper/sumi; only the timer floats on glass.
struct FocusLayoutView: View {
    var body: some View {
        HStack(alignment: .top, spacing: Spacing.xLarge) {
            FocusDayColumnView().frame(width: 240)
            Divider().overlay(Palette.hairline.color)
            FocusBlockView().frame(maxWidth: .infinity, alignment: .leading)
            FocusSideColumnView().frame(width: 300)
        }
        .frame(width: 1180, height: 620, alignment: .top)
    }
}

struct FocusDayColumnView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xLarge) {
            section("To do", MockupDay.toDo)
            section("In progress", MockupDay.inProgress)
            section("Done", MockupDay.done)
        }
    }

    private func section(_ title: String, _ items: [MockupDay.Item]) -> some View {
        MockupSectionView(title: title) {
            ForEach(items) { TaskRowView(title: $0.title, priority: $0.priority, isCompleted: $0.isCompleted) }
        }
    }
}

struct FocusBlockView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            Text("14:00 – 15:30 · Work").sectionLabel()
            Text("Write the M2 design record").font(TypeScale.title).foregroundStyle(Palette.ink.color)
            Text("Palette, glass rules and the Focus layout, with screenshots in light and dark.")
                .font(TypeScale.body)
                .foregroundStyle(Palette.inkMuted.color)
            MockupSectionView(title: "Subtasks") {
                ForEach(MockupDay.subtasks) {
                    TaskRowView(title: $0.title, priority: $0.priority, isCompleted: $0.isCompleted)
                }
            }
            .padding(Spacing.large)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface.color, in: .rect(cornerRadius: Radius.large))
        }
    }
}

struct FocusSideColumnView: View {
    @State private var notes = "Contrast pinned in tests; dark shu moved to #D0462C."

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xLarge) {
            TimerGlassView(phase: .focus, remaining: "18:42", progress: 0.25).frame(maxWidth: .infinity)
            MockupSectionView(title: "Session notes") {
                TextEditor(text: $notes)
                    .font(TypeScale.body)
                    .scrollContentBackground(.hidden)
                    .padding(Spacing.small)
                    .frame(height: 96)
                    .background(Palette.surface.color, in: .rect(cornerRadius: Radius.medium))
            }
        }
    }
}

#Preview("Focus, light") { FocusLayoutView().mockupCanvas(.light) }
#Preview("Focus, dark") { FocusLayoutView().mockupCanvas(.dark) }
