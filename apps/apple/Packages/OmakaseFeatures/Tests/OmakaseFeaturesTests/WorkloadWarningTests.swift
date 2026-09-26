import OmakaseStore
import Testing

@testable import OmakaseFeatures

struct WorkloadWarningTests {
    @Test func noCachedWorkloadSaysNothing() {
        let warning = WorkloadWarning(record: nil)
        #expect(warning.level == .none && warning.text == nil)
    }

    @Test func anEmptyDaySaysNothing() {
        let warning = WorkloadWarning(planned: 0, goal: 720, unestimatedCount: 0)
        #expect(warning.level == .none && warning.text == nil && !warning.isPartial)
    }

    @Test func aDayWithinTheGoalSaysHowMuchIsPlanned() {
        let warning = WorkloadWarning(planned: 300, goal: 720, unestimatedCount: 0)
        #expect(warning.level == .within(planned: 300, goal: 720))
        #expect(warning.text == "5h planned of 12h")
    }

    @Test func aDayExactlyAtTheGoalIsWithinIt() {
        #expect(WorkloadWarning(planned: 720, goal: 720, unestimatedCount: 0).level == .within(planned: 720, goal: 720))
    }

    @Test func aDayOverTheGoalSaysByHowMuch() {
        let warning = WorkloadWarning(planned: 810, goal: 720, unestimatedCount: 0)
        #expect(warning.level == .over(excess: 90, goal: 720) && warning.isOver)
        #expect(warning.text == "1h 30m over your 12h goal")
    }

    @Test func minutesUnderAnHourReadAsMinutes() {
        #expect(WorkloadWarning(planned: 50, goal: 720, unestimatedCount: 0).text == "50m planned of 12h")
    }

    @Test func unestimatedItemsMakeTheSumPartial() {
        let warning = WorkloadWarning(planned: 300, goal: 720, unestimatedCount: 2)
        #expect(warning.isPartial && !warning.isOver)
        #expect(warning.text == "5h planned of 12h · 2 without an estimate")
    }

    @Test func aDayOfOnlyUnestimatedItemsStillSaysSo() {
        // Items without an estimate are planned: the sum is 0 but not empty.
        let warning = WorkloadWarning(planned: 0, goal: 720, unestimatedCount: 3)
        #expect(warning.text == "0m planned of 12h · 3 without an estimate")
    }

    @MainActor @Test func theWarningReadsTheCachedRecord() {
        let record = WorkloadRecord(day: "2026-03-07")
        (record.plannedMinutes, record.goalMinutes, record.unestimatedCount) = (800, 720, 1)
        let warning = WorkloadWarning(record: record)
        #expect(warning.level == .over(excess: 80, goal: 720) && warning.isPartial)
    }
}
