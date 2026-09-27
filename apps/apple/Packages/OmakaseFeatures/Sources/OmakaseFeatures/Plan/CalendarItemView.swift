import SwiftUI

/// A block or a class on the grid (design-system-apple, Signals): a block
/// is its source colour as a 3-pt bar and a faint fill on an opaque
/// surface; a class is dashed with a book glyph, because it is fixed, not
/// planned. A cancelled class stays, struck through and dimmed (#207): it
/// is information, not absence.
struct CalendarItemView: View {
    let item: CalendarItem

    private var isClass: Bool { item.kind == .classOccurrence }
    private var isCancelled: Bool { isClass && item.isCancelled }

    var body: some View {
        let tint = item.color.color
        HStack(alignment: .top, spacing: Spacing.tiny) {
            if isClass {
                Image(systemName: "book").font(TypeScale.caption).foregroundStyle(tint)
            } else {
                Capsule().fill(tint).frame(width: 3)
            }
            Text(item.title).font(TypeScale.caption.weight(.medium)).foregroundStyle(Palette.ink.color)
                .strikethrough(isCancelled)
            Spacer(minLength: 0)
        }
        .padding(Spacing.tiny)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(tint.opacity(isClass ? 0.06 : 0.14), in: .rect(cornerRadius: Radius.small))
        // Opaque under the tint, so neither the hour lines nor the desktop
        // show through a block.
        .background(Palette.surface.color, in: .rect(cornerRadius: Radius.small))
        .overlay { if isClass { dashedBorder(tint) } }
        .clipShape(.rect(cornerRadius: Radius.small))
        .opacity(isCancelled ? 0.45 : 1)
        .help(isCancelled ? "\(item.title), cancelled" : item.title)
    }

    private func dashedBorder(_ tint: Color) -> some View {
        RoundedRectangle(cornerRadius: Radius.small).strokeBorder(tint.opacity(0.5), style: .init(dash: [4, 3]))
    }
}

/// A focus session that ran: a thin rounded lane at the column's trailing
/// edge, in ink, because what happened is not a signal (R8).
struct CalendarSessionView: View {
    let item: CalendarItem

    var body: some View {
        RoundedRectangle(cornerRadius: CalendarLayout.sessionLaneWidth / 2)
            .fill(Palette.ink.color.opacity(0.3))
            .help(item.title)
    }
}

/// Now: a shu dot and line across today's column, shu's one place on Plan.
struct CalendarNowMarkView: View {
    static let dot: CGFloat = 7

    var body: some View {
        HStack(spacing: 0) {
            Circle().fill(Palette.shu.color).frame(width: Self.dot, height: Self.dot)
            Rectangle().fill(Palette.shu.color).frame(height: 1.5)
        }
        .accessibilityLabel("Now")
    }
}
