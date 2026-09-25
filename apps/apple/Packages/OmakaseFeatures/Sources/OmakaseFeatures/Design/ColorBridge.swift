import SwiftUI

#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

extension DesignColor {
    /// The token as a SwiftUI colour that follows the system appearance live.
    public var color: Color {
        #if os(macOS)
            Color(nsColor: nsColor)
        #else
            Color(uiColor: uiColor)
        #endif
    }

    func side(dark: Bool) -> RGB { dark ? self.dark : light }
}

extension RGB {
    #if os(macOS)
        var nsColor: NSColor { NSColor(srgbRed: red, green: green, blue: blue, alpha: 1) }
    #else
        var uiColor: UIColor { UIColor(red: red, green: green, blue: blue, alpha: 1) }
    #endif
}

#if os(macOS)
    extension DesignColor {
        var nsColor: NSColor {
            let token = self
            return NSColor(name: nil) { appearance in
                token.side(dark: appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua).nsColor
            }
        }
    }
#else
    extension DesignColor {
        var uiColor: UIColor {
            let token = self
            return UIColor { traits in token.side(dark: traits.userInterfaceStyle == .dark).uiColor }
        }
    }
#endif
