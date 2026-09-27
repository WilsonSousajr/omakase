import Foundation
import Testing

@testable import OmakaseAPI

/// Recurring tasks on the wire (#124, #206): a series' occurrences, computed
/// or stored, and its rule.
struct TaskRecurrenceDTOTests {
    private let base = URL(string: "http://localhost:8000")!

    @Test func todayKeepsASeriesComputedOccurrence() throws {
        // #206 replaces #124's stopgap, which dropped it: it has no id, but a series and a date.
        let page = try OmakaseJSON.decoder.decode(Page<TaskDTO>.self, from: Fixture.data("tasks_today"))
        let virtual = try #require(page.results.last)
        #expect(virtual.id == nil && virtual.isVirtual && !virtual.isSkipped)
        #expect(virtual.series?.uuidString.lowercased() == "3859d72d-762d-45b2-a106-b19ca97ef5e4")
        #expect(virtual.occurrenceDate?.string == "2026-03-07" && virtual.subtasks == [])
        #expect(virtual.recurrence?.freq == "weekly" && virtual.recurrence?.weekdays == [])
    }

    @Test func aPlainTaskHasNoSeries() throws {
        let page = try OmakaseJSON.decoder.decode(Page<TaskDTO>.self, from: Fixture.data("tasks_today"))
        let row = try #require(page.results.first)
        #expect(row.id != nil && !row.isVirtual && row.series == nil && row.recurrence == nil)
        #expect(row.occurrenceDate == nil)
    }

    @Test func theRulePutAnswersWithTheTaskInItsSeries() throws {
        let task = try OmakaseJSON.decoder.decode(TaskDTO.self, from: Fixture.data("task_recurrence"))
        let rule = try #require(task.recurrence)
        #expect(task.series != nil && task.occurrenceDate?.string == "2026-03-02")
        #expect(rule.freq == "weekly" && rule.interval == 1 && rule.weekdays == [0, 2])
        #expect(rule.startsOn.string == "2026-03-02" && rule.until?.string == "2026-06-30")
    }

    @Test func theMaterializePutAnswersWithAStoredOccurrence() throws {
        let task = try OmakaseJSON.decoder.decode(TaskDTO.self, from: Fixture.data("task_occurrence"))
        #expect(task.id != nil && !task.isVirtual && task.occurrenceDate?.string == "2026-03-04")
    }

    @Test func occurrencesAreAPlainListForTheRange() async throws {
        let transport = FakeHTTPTransport([
            .success(.init(status: 200, body: try Fixture.data("tasks_occurrences_range")))
        ])
        let tokens = InMemoryTokenStore(.init(access: "a1", refresh: "r1"))
        let api = OmakaseAPIClient(baseURL: base, transport: transport, tokens: tokens)
        let items = try await api.occurrences(from: APIDay(string: "2026-03-02")!, to: APIDay(string: "2026-03-08")!)
        #expect(items.map(\.isVirtual) == [false, true])
        let sent = await transport.sent.compactMap { $0.url.map { $0.path() + "?" + ($0.query() ?? "") } }
        #expect(sent == ["/api/v1/tasks/occurrences/?date_from=2026-03-02&date_to=2026-03-08"])
    }
}
