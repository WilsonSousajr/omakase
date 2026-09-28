import Foundation
import Testing

@testable import OmakaseFeatures

/// A class cancelled on its date and restored from Plan's context menu (#207).
@MainActor
struct PlanClassCancellationTests {
    let recorder = PlanActionsRecorder()

    func model() -> PlanModel { PlanModel(actions: recorder.actions) { "2026-09-23" } }

    func lecture(cancelled: Bool) -> CalendarItem {
        CalendarItem(
            id: "s1-2026-09-23", day: "2026-09-23", start: 480, end: 580, title: "Calculus", kind: .classOccurrence,
            isCancelled: cancelled)
    }

    @Test func aClassOnTimeOffersToBeCancelled() {
        let item = lecture(cancelled: false)
        #expect(item.cancellationMenuTitle == "Cancel this class")
        model().toggleCancellation(item)
        #expect(recorder.calls == ["cancel class s1-2026-09-23"])
    }

    @Test func aCancelledClassOffersToBeRestored() {
        let item = lecture(cancelled: true)
        #expect(item.cancellationMenuTitle == "Restore class")
        model().toggleCancellation(item)
        #expect(recorder.calls == ["restore class s1-2026-09-23"])
    }

    @Test func aBlockIsNeverCancelled() {
        let block = CalendarItem(id: "b1", day: "2026-09-23", start: 480, end: 540, title: "Essay", kind: .block)
        model().toggleCancellation(block)
        #expect(recorder.calls.isEmpty)
    }

    @Test func theDefaultActionsDoNothing() {
        PlanModel(actions: .none) { "2026-09-23" }.toggleCancellation(lecture(cancelled: false))
    }
}
