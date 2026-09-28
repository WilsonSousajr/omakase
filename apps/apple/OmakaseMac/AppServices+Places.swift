import Foundation
import OmakaseFeatures
import OmakaseStore

extension AppServices {
    /// A place's open tasks (spec §5): read while it shows, and again after
    /// each catch-up (`handle()`). Offline or on error, `PlaceSync` leaves
    /// the cache as it was.
    func placesActions() -> PlaceListModel.Actions {
        let sync = PlaceSync(api: api, context: container.mainContext)
        return PlaceListModel.Actions(refresh: { [self] place in placeRefresh(sync, place) })
    }

    private func placeRefresh(_ sync: PlaceSync, _ place: TaskPlace) {
        Task { try? await sync.refresh(place, today: FocusDay().today) }
    }
}
