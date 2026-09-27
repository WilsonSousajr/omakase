import Testing

@testable import OmakaseFeatures

/// Pins the kind colours measured in the spec (§2): legible on `background`
/// in both appearances, and far enough from every other signal colour that
/// a later palette change cannot make two meanings look alike.
struct KindTintTests {
    static let kinds: [(String, DesignColor)] = [
        ("work", KindTint.work), ("study", KindTint.study), ("life", KindTint.life),
    ]
    static let otherSignals: [(String, DesignColor)] = [
        ("shu", Palette.shu), ("matcha", Palette.matcha), ("indigo", Palette.indigo),
        ("priority low", PriorityMark.low), ("priority medium", PriorityMark.medium),
        ("priority high", PriorityMark.high), ("priority urgent", PriorityMark.urgent),
    ]

    @Test func everyKindMeetsThreeToOneOnBackground() {
        for (name, kind) in Self.kinds {
            #expect(RGB.contrast(kind.dark, Palette.background.dark) >= 3, "\(name) dark")
            #expect(RGB.contrast(kind.light, Palette.background.light) >= 3, "\(name) light")
        }
    }

    @Test func everyKindIsFarFromTheOtherSignalColours() {
        for (name, kind) in Self.kinds {
            for (otherName, other) in Self.otherSignals {
                #expect(ColorDistance.deltaE76(kind.dark, other.dark) >= 20, "\(name) vs \(otherName) dark")
                #expect(ColorDistance.deltaE76(kind.light, other.light) >= 20, "\(name) vs \(otherName) light")
            }
        }
    }

    @Test func everyKindIsFarFromTheOtherKinds() {
        for firstIndex in 0..<Self.kinds.count {
            for secondIndex in (firstIndex + 1)..<Self.kinds.count {
                let (nameA, colorA) = Self.kinds[firstIndex]
                let (nameB, colorB) = Self.kinds[secondIndex]
                #expect(ColorDistance.deltaE76(colorA.dark, colorB.dark) >= 20, "\(nameA) vs \(nameB) dark")
                #expect(ColorDistance.deltaE76(colorA.light, colorB.light) >= 20, "\(nameA) vs \(nameB) light")
            }
        }
    }

    @Test func markPrefersALegibleParentColour() {
        let mark = KindTint.mark(for: .work, parentHex: "#3b82f6")
        #expect(mark == DesignColor(hex: "#3b82f6"))
    }

    @Test func markFallsBackWhenTheParentColourIsIllegibleInDark() {
        #expect(KindTint.mark(for: .work, parentHex: "#1A1A1A") == KindTint.work)
    }

    @Test func markFallsBackWhenTheHexIsInvalid() {
        #expect(KindTint.mark(for: .study, parentHex: "blue") == KindTint.study)
    }

    @Test func markFallsBackWhenThereIsNoParent() {
        #expect(KindTint.mark(for: .life, parentHex: nil) == KindTint.life)
    }
}
