import OmakaseStore
import Testing

@testable import OmakaseFeatures

/// A parent menu's sections (spec §4): a kind's places split into runs of
/// the same workspace, in the directory's order.
struct PlaceGroupTests {
    private func project(_ id: String, _ title: String, group: String?) -> PlaceEntry {
        PlaceEntry(parent: .project(id), title: title, group: group, color: KindTint.work)
    }

    @Test func noPlacesMakeNoGroups() {
        #expect(PlaceGroup.groups(of: []).isEmpty)
    }

    @Test func ungroupedPlacesMakeOneUntitledGroup() {
        let entries = [project("p1", "Thesis", group: nil), project("p2", "Garden", group: nil)]
        #expect(PlaceGroup.groups(of: entries) == [PlaceGroup(title: nil, entries: entries)])
    }

    @Test func eachWorkspaceGetsItsOwnGroupInOrder() {
        let client = [project("p1", "Audit", group: "Client"), project("p2", "Site", group: "Client")]
        let home = [project("p3", "Garden", group: "Home")]
        #expect(
            PlaceGroup.groups(of: client + home)
                == [PlaceGroup(title: "Client", entries: client), PlaceGroup(title: "Home", entries: home)])
    }

    @Test func aGroupIsIdentifiedByItsTitle() {
        #expect(PlaceGroup(title: "Home", entries: []).id == "Home")
        #expect(PlaceGroup(title: nil, entries: []).id == "")
    }
}
