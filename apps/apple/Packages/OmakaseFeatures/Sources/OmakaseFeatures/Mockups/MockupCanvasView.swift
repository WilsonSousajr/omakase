import SwiftUI

/// The fake day every M2 mockup draws, so the screenshots in
/// docs/design-system-apple.md tell one story.
enum MockupDay {
    struct Item: Identifiable {
        let id = UUID()
        let title: String
        let priority: String
        var isCompleted = false
    }

    static let toDo = [
        Item(title: "Outline the thesis chapter", priority: "urgent"),
        Item(title: "Review pull request #112", priority: "high"),
        Item(title: "Linear algebra problem set", priority: "medium"),
        Item(title: "Reply to the lab's email", priority: "low"),
    ]
    static let inProgress = [Item(title: "Write the M2 design record", priority: "high")]
    static let done = [
        Item(title: "Morning review", priority: "medium", isCompleted: true),
        Item(title: "Read chapter 4", priority: "low", isCompleted: true),
    ]
    static let subtasks = [
        Item(title: "Palette and contrast", priority: "", isCompleted: true),
        Item(title: "Glass rules", priority: ""),
        Item(title: "Screenshots, light and dark", priority: ""),
    ]
}

extension View {
    /// A mockup on the app's opaque ground in one appearance.
    func mockupCanvas(_ scheme: ColorScheme) -> some View {
        padding(Spacing.xxLarge)
            .background(Palette.background.color)
            .preferredColorScheme(scheme)
            .environment(\.colorScheme, scheme)
    }
}

/// A list section: the section label over its rows.
struct MockupSectionView<Rows: View>: View {
    let title: String
    @ViewBuilder let rows: Rows

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text(title).sectionLabel()
            rows
        }
    }
}
