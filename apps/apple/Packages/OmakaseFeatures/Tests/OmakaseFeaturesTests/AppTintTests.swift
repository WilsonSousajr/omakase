import Foundation
import Testing

@testable import OmakaseFeatures

/// The chrome is monochrome whatever the user's system accent
/// (docs/design-system-apple.md, M2): every host of SwiftUI applies
/// `Palette.accent`, and the asset catalog's `AccentColor` is the same grey.
struct AppTintTests {
    /// macOS honours an app's `AccentColor` only while the system accent is
    /// Multicolor; with another one chosen, anything the app does not tint
    /// itself takes the user's colour. The sidebar icons and the capture
    /// panel's caret were purple on a Mac set to purple (#214).
    @Test func everyHostAppliesTheGreyAccentIssue214() {
        let hosts = [AppTint.window, AppTint.sidebarIcons, AppTint.menuBarPanel, AppTint.capturePanel]
        for host in hosts {
            #expect(host == Palette.accent)
        }
    }

    /// The catalog's colour is what the system draws with under Multicolor,
    /// before any `.tint` applies, so it must be `Palette.accent` too.
    @Test func assetCatalogAccentIsPaletteAccent() throws {
        let colours = try Self.catalogAccent()
        #expect(colours.light == Palette.accent.light)
        #expect(colours.dark == Palette.accent.dark)
    }

    /// The light and dark sides of `OmakaseMac/Assets.xcassets/AccentColor`.
    private static func catalogAccent() throws -> (light: RGB, dark: RGB) {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().appending(path: "../../../../OmakaseMac/Assets.xcassets")
            .appending(path: "AccentColor.colorset/Contents.json")
        let catalog = try JSONDecoder().decode(ColorSet.self, from: Data(contentsOf: url))
        let light = try #require(catalog.colors.first { $0.appearances == nil })
        let dark = try #require(catalog.colors.first { $0.appearances != nil })
        return (try light.color.components.rgb(), try dark.color.components.rgb())
    }
}

/// The part of an asset catalog colour set this test reads.
private struct ColorSet: Decodable {
    struct Entry: Decodable {
        struct Appearance: Decodable { let value: String }
        let appearances: [Appearance]?
        let color: Swatch
    }
    struct Swatch: Decodable { let components: Components }
    struct Components: Decodable {
        let red: String
        let green: String
        let blue: String

        /// The components are written as hex bytes, `"0x6F"`.
        func rgb() throws -> RGB {
            let bytes = try [red, green, blue].map { raw in
                try #require(UInt32(raw.dropFirst(2), radix: 16), "component \(raw) is not 0xNN")
            }
            return RGB(bytes[0] << 16 | bytes[1] << 8 | bytes[2])
        }
    }
    let colors: [Entry]
}
