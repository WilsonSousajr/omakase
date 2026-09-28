/// How an item on the Plan grid wears its colour (glass-pass §1, #283): as
/// marks only. S10's faint tint under a block is gone. A block is opaque
/// `surface` with its colour as a 3-pt bar; a class, which has no bar,
/// keeps its dashed border and its book glyph in its colour.
///
///     let look = CalendarItemLook(item)   // look.fill == Palette.surface
struct CalendarItemLook: Equatable {
    /// Opaque, so neither the hour lines nor the desktop show through.
    let fill: DesignColor
    /// A block's leading bar; nil for a class, which is dashed instead.
    let bar: DesignColor?
    /// The glyph: a block's kind beside its title, quiet; a class's book,
    /// in its colour, where a block has its bar.
    let glyph: DesignColor
    /// A class's dashed border; nil for a block.
    let dash: DesignColor?
}

extension CalendarItemLook {
    /// The look `item` gets: its colour on the bar (a block) or on the book
    /// and the dashes (a class), and never as a fill.
    init(_ item: CalendarItem) {
        let isClass = item.kind == .classOccurrence
        self.init(
            fill: Palette.surface, bar: isClass ? nil : item.color, glyph: isClass ? item.color : Palette.inkMuted,
            dash: isClass ? item.color : nil)
    }
}
