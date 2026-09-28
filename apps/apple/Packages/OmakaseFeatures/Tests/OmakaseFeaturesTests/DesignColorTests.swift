import Testing

@testable import OmakaseFeatures

struct DesignColorTests {
    @Test func hexSplitsIntoChannels() {
        let rgb = RGB(0xFF8000)
        #expect(rgb.red == 1)
        #expect(abs(rgb.green - 128.0 / 255) < 1e-9)
        #expect(rgb.blue == 0)
    }

    @Test func blackOnWhiteIsTwentyOne() {
        #expect(abs(RGB.contrast(RGB(0x000000), RGB(0xFFFFFF)) - 21) < 1e-9)
    }

    @Test func contrastIgnoresArgumentOrder() {
        #expect(RGB.contrast(RGB(0x777777), RGB(0xFFFFFF)) == RGB.contrast(RGB(0xFFFFFF), RGB(0x777777)))
        #expect(RGB.contrast(RGB(0xFFFFFF), RGB(0xFFFFFF)) == 1)
    }

    /// #777 on white is the textbook "just misses AA" pair (4.48:1).
    @Test func greyOnWhiteMatchesTheWCAGReference() {
        #expect(abs(RGB.contrast(RGB(0x777777), RGB(0xFFFFFF)) - 4.48) < 0.01)
    }
}
