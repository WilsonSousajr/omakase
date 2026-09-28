import OmakaseStore
import Testing

@testable import OmakaseFeatures

/// The place shown on screen (spec §5): read now, and again on a catch-up
/// only while it stays shown, as `PlanModelWritesTests` proves for Plan's days.
@MainActor
struct PlaceListModelTests {
    final class Recorder {
        var refreshed: [TaskPlace] = []
    }

    private let recorder = Recorder()

    private func model() -> PlaceListModel {
        let recorder = recorder
        return PlaceListModel(actions: .init(refresh: { recorder.refreshed.append($0) }))
    }

    @Test func showingAPlaceRefreshesItAndRecordsItAsShown() {
        let places = model()
        places.show(.discipline("d1"))
        #expect(places.shown == .discipline("d1"))
        #expect(recorder.refreshed == [.discipline("d1")])
    }

    @Test func aCatchUpRefreshesOnlyWhileAPlaceShows() {
        let places = model()
        places.caughtUp()
        places.show(.project("p1"))
        places.caughtUp()
        places.hide()
        places.caughtUp()
        #expect(recorder.refreshed == [.project("p1"), .project("p1")])
    }

    @Test func refreshWithNothingShownDoesNothing() {
        model().refresh()
        #expect(recorder.refreshed.isEmpty)
    }

    @Test func hidingClearsTheShownPlace() {
        let places = model()
        places.show(.life)
        places.hide()
        #expect(places.shown == nil)
    }

    @Test func showingADifferentPlaceReplacesTheOneShown() {
        let places = model()
        places.show(.life)
        places.show(.discipline("d2"))
        places.caughtUp()
        #expect(recorder.refreshed == [.life, .discipline("d2"), .discipline("d2")])
    }

    @Test func withNoActionsShowingStillAnswers() {
        let places = PlaceListModel()
        places.show(.life)
        #expect(places.shown == .life)
    }
}
