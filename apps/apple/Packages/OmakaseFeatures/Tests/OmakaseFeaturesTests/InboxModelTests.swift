import Foundation
import OmakaseStore
import Testing

@testable import OmakaseFeatures

/// The Inbox (#225): tasks with no date, triaged to a day, done, edited or deleted.
@MainActor
struct InboxModelTests {
    final class Recorder {
        var scheduled: [(String, String?)] = []
        var toggled: [String] = []
        var deleted: [String] = []
        var edited: [(String, TaskEdit)] = []
    }

    private let recorder = Recorder()

    private func model() -> InboxModel {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        let recorder = recorder
        return InboxModel(
            actions: .init(
                schedule: { recorder.scheduled.append(($0, $1)) }, toggle: { recorder.toggled.append($0) },
                delete: { recorder.deleted.append($0) }, edit: { recorder.edited.append(($0, $1)) }),
            calendar: calendar, today: { "2026-09-27" })
    }

    @Test func todayAndTomorrowAreTheClientsDays() {
        let inbox = model()
        inbox.schedule("t1", .today)
        inbox.schedule("t2", .tomorrow)
        #expect(recorder.scheduled.map(\.1) == ["2026-09-27", "2026-09-28"])
    }

    @Test func aPickedDateIsItsDayInTheCalendar() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 3, hour: 23)))
        model().schedule("t1", .date(date))
        #expect(recorder.scheduled.first?.1 == "2026-10-03")
    }

    @Test func completingToggles() {
        model().complete("t1")
        #expect(recorder.toggled == ["t1"])
    }

    @Test func deletingAsksFirst() {
        let inbox = model()
        inbox.askToDelete("t1")
        #expect(inbox.deletingID == "t1" && recorder.deleted.isEmpty)
        inbox.confirmDelete()
        #expect(recorder.deleted == ["t1"] && inbox.deletingID == nil)
    }

    @Test func cancellingADeleteDeletesNothing() {
        let inbox = model()
        inbox.askToDelete("t1")
        inbox.cancelDelete()
        inbox.confirmDelete()
        #expect(recorder.deleted.isEmpty && inbox.deletingID == nil)
    }

    @Test func editingOpensTheEditorAndSavesThroughTheAction() {
        let inbox = model()
        inbox.beginEditing("t1")
        #expect(inbox.editingID == "t1")
        inbox.saveEdit("t1", TaskEdit(title: "Renamed"))
        #expect(recorder.edited.first?.0 == "t1" && recorder.edited.first?.1.title == "Renamed")
    }

    @Test func theBadgeCountsOpenTasksAndHidesAtZero() {
        #expect(InboxModel.badge(count: 0) == 0 && InboxModel.badge(count: 4) == 4)
    }
}
