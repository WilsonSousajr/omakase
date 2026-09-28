import OmakaseStore
import SwiftUI

/// A sidebar row: its title and symbol, and for the Inbox the count of what
/// waits there (#225). A zero count is hidden, as the badge's was. The
/// count comes from `SidebarView`'s one query of open tasks (#260) rather
/// than a query per row.
///
///     SidebarRowView(item: .inbox, count: TriageModel.badge(count: counts.inbox))
public struct SidebarRowView: View {
    private let item: SidebarItem
    private let count: Int

    public init(item: SidebarItem, count: Int = 0) { (self.item, self.count) = (item, count) }

    public var body: some View {
        SidebarCountedRowView(count: count) { Label(item.title, systemImage: item.symbol) }
    }
}

/// A kind's header (spec §6): monochrome, its glyph and name, counting
/// what its places hold. Selecting it opens the kind's screen.
struct SidebarKindHeaderView: View {
    let section: SidebarKindSection

    var body: some View {
        SidebarCountedRowView(count: section.count) {
            Label(section.area.title, systemImage: section.area.symbol)
        }
    }
}

/// A place under its kind (glass-pass §2): a 6-pt dot in the place's
/// colour — colour only as a mark — where a glyph would sit, its name, and
/// its open tasks.
struct SidebarPlaceRowView: View {
    let row: SidebarPlaceRow

    var body: some View {
        SidebarCountedRowView(count: row.count) {
            Label {
                Text(row.title).lineLimit(1).truncationMode(.tail)
            } icon: {
                Circle().fill(row.color.color).frame(width: ControlMetrics.markDot, height: ControlMetrics.markDot)
                    .frame(width: SidebarMetrics.iconColumn)
                    .accessibilityHidden(true)
            }
        }
    }
}

/// A workspace's name or the semester's title over its places, in line
/// with their names: a label, never a selection.
struct SidebarSubheaderView: View {
    let title: String

    var body: some View {
        Label {
            Text(title).sectionLabel().lineLimit(1)
        } icon: {
            Color.clear.frame(width: SidebarMetrics.iconColumn, height: ControlMetrics.markDot)
        }
    }
}

/// A row's content with its count at the trailing edge.
struct SidebarCountedRowView<Content: View>: View {
    let count: Int
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: Spacing.small) {
            content
            Spacer(minLength: Spacing.small)
            SidebarCountView(count: count)
        }
    }
}

/// An open-task count: muted, tabular, rolling to its new value (spec §6,
/// `Motion.digits`). Zero shows nothing, as the Inbox badge's zero did.
struct SidebarCountView: View {
    let count: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if count > 0 {
            Text(count, format: .number)
                .font(TypeScale.caption)
                .monospacedDigit()
                .foregroundStyle(Palette.inkMuted.color)
                .contentTransition(Motion.digits(reduceMotion: reduceMotion))
                .motion(Motion.select, value: count)
        }
    }
}
