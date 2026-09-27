import OmakaseStore
import Testing

@testable import OmakaseFeatures

/// Pins each kind's title, glyph and capture shortcut (spec §2, §4).
struct TaskAreaPresentationTests {
    @Test func titlesNameEachKind() {
        #expect(TaskArea.work.title == "Work")
        #expect(TaskArea.study.title == "Study")
        #expect(TaskArea.life.title == "Life")
    }

    @Test func symbolsMatchEachKind() {
        #expect(TaskArea.work.symbol == "briefcase")
        #expect(TaskArea.study.symbol == "graduationcap")
        #expect(TaskArea.life.symbol == "leaf")
    }

    @Test func shortcutDigitsPickEachKindInOrder() {
        #expect(TaskArea.work.shortcutDigit == 1)
        #expect(TaskArea.study.shortcutDigit == 2)
        #expect(TaskArea.life.shortcutDigit == 3)
    }
}
