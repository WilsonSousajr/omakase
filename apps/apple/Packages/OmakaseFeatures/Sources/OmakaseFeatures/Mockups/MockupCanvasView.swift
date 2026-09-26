import SwiftUI

/// The fake day every M2 mockup draws, so the screenshots in
/// docs/design-system-apple.md tell one story.
enum MockupDay {
    struct Item: Identifiable {
        let id = UUID()
        let title: String
        let priority: String
        var minutes = 0
        var isCompleted = false
    }

    /// A time block on the calendar. `source` is its project or discipline
    /// colour; a class occurrence is drawn behind, dashed (IDEA.md, calendar).
    struct Block: Identifiable {
        let id = UUID()
        let title: String
        let start: Double
        let hours: Double
        let source: DesignColor
        var isClass = false
    }

    static let toDo = [
        Item(title: "Outline the thesis chapter", priority: "urgent", minutes: 90),
        Item(title: "Review pull request #112", priority: "high", minutes: 30),
        Item(title: "Linear algebra problem set", priority: "medium", minutes: 60),
        Item(title: "Reply to the lab's email", priority: "low", minutes: 15),
    ]
    static let inProgress = [Item(title: "Write the M2 design record", priority: "high", minutes: 90)]
    static let done = [
        Item(title: "Morning review", priority: "medium", minutes: 15, isCompleted: true),
        Item(title: "Read chapter 4", priority: "low", minutes: 45, isCompleted: true),
    ]
    static let subtasks = [
        Item(title: "Palette and contrast", priority: "", isCompleted: true),
        Item(title: "Glass rules", priority: ""),
        Item(title: "Screenshots, light and dark", priority: ""),
    ]
    static let studyBlocks = ["Linear algebra · 45m", "Thesis reading · 30m"]

    static let blocks = [
        Block(title: "Morning review", start: 8.5, hours: 0.5, source: Palette.inkMuted),
        Block(title: "Linear algebra lecture", start: 10, hours: 1.5, source: Palette.indigo, isClass: true),
        Block(title: "Read chapter 4", start: 12, hours: 0.75, source: Palette.matcha),
        Block(title: "Write the M2 design record", start: 14, hours: 1.5, source: PriorityMark.medium),
        Block(title: "Linear algebra problem set", start: 16, hours: 1, source: Palette.indigo),
    ]
    /// 14:40, where the current-time line sits.
    static let now = 14.67
}

/// A stand-in desktop, busy on purpose, so the mockups show what the
/// translucent ground and the glass do over a real wallpaper.
struct MockupDesktopView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Palette.indigo.color, Palette.matcha.color, PriorityMark.medium.color],
                startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(Palette.indigo.color).frame(width: 420).offset(x: 260, y: -140).blur(radius: 30)
            Circle().fill(.white.opacity(0.8)).frame(width: 300).offset(x: -320, y: 180).blur(radius: 20)
        }
    }
}

extension View {
    /// A floating surface (timer, capture) over the stand-in desktop.
    func mockupCanvas(_ scheme: ColorScheme) -> some View {
        padding(Spacing.xxLarge)
            .background { MockupDesktopView() }
            .preferredColorScheme(scheme)
            .environment(\.colorScheme, scheme)
    }

    /// A window-sized mockup on the translucent ground over the stand-in
    /// desktop: what `omakaseWindowBackground()` draws in the app.
    func mockupWindow(_ scheme: ColorScheme) -> some View {
        background {
            ZStack {
                MockupDesktopView()
                Rectangle().fill(.ultraThinMaterial)
                Palette.background.color.opacity(Translucency.window)
            }
        }
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
