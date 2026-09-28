import OmakaseStore
import Testing

@testable import OmakaseFeatures

/// The sidebar's persisted selection (spec §3): an item or a place, saved by
/// its raw value so `@SceneStorage` survives a relaunch (#256).
struct SidebarSelectionTests {
    @Test func everyItemRoundTripsThroughItsRawValue() {
        for item in SidebarItem.allCases {
            let selection = SidebarSelection.item(item)
            #expect(SidebarSelection(rawValue: selection.rawValue) == selection)
        }
    }

    @Test func everyPlaceKindRoundTripsThroughItsRawValue() {
        let places: [TaskPlace] = [.project("42"), .discipline("7"), .life]
        for place in places {
            let selection = SidebarSelection.place(place)
            #expect(SidebarSelection(rawValue: selection.rawValue) == selection)
        }
    }

    @Test func rawValuesMatchTheSpelledOutFormat() {
        #expect(SidebarSelection.item(.focus).rawValue == "focus")
        #expect(SidebarSelection.place(.project("42")).rawValue == "place.project.42")
        #expect(SidebarSelection.place(.discipline("7")).rawValue == "place.discipline.7")
        #expect(SidebarSelection.place(.life).rawValue == "place.life")
    }

    @Test func anUnknownRawValueIsNil() {
        #expect(SidebarSelection(rawValue: "zzz") == nil)
        #expect(SidebarSelection(rawValue: "place.bogus.1") == nil)
    }

    @Test func validKeepsAKnownPlace() {
        let selection = SidebarSelection.place(.project("42"))
        #expect(selection.valid(knownPlaces: [.project("42")]) == selection)
    }

    @Test func validKeepsAnItem() {
        let selection = SidebarSelection.item(.plan)
        #expect(selection.valid(knownPlaces: []) == selection)
    }

    @Test func validFallsBackToFocusForAPlaceMissingFromTheSet() {
        let selection = SidebarSelection.place(.project("42"))
        #expect(selection.valid(knownPlaces: [.discipline("7")]) == .item(.focus))
    }
}
