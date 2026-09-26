import Foundation
import Testing

@testable import OmakaseAPI

struct DayAPIClientTests {
    private let base = URL(string: "http://localhost:8000")!
    private let day = APIDay(string: "2026-03-07")!

    private func client(
        _ replies: [Result<FakeHTTPTransport.Reply, URLError>]
    ) -> (OmakaseAPIClient, FakeHTTPTransport) {
        let transport = FakeHTTPTransport(replies)
        let tokens = InMemoryTokenStore(.init(access: "a1", refresh: "r1"))
        return (OmakaseAPIClient(baseURL: base, transport: transport, tokens: tokens), transport)
    }

    private func sentURL(_ transport: FakeHTTPTransport) async -> String? {
        let request = await transport.sent.first
        return request?.url.map { $0.path() + "?" + ($0.query() ?? "") }
    }

    @Test func carriedOverSendsTheDay() async throws {
        let (api, transport) = client([.success(.init(status: 200, body: try Fixture.data("tasks_carried_over")))])
        #expect(try await api.carriedOver(on: day).count == 1)
        #expect(await sentURL(transport) == "/api/v1/tasks/carried-over/?date=2026-03-07")
    }

    @Test func timeBlocksSendTheDay() async throws {
        let (api, transport) = client([.success(.init(status: 200, body: try Fixture.data("timeblocks_day")))])
        #expect(try await api.timeBlocks(on: day).count == 1)
        #expect(await sentURL(transport) == "/api/v1/timeblocks/?date=2026-03-07")
    }

    @Test func studyBlocksFilterByScheduledDate() async throws {
        let (api, transport) = client([.success(.init(status: 200, body: try Fixture.data("studyblocks_day")))])
        #expect(try await api.studyBlocks(on: day).count == 1)
        #expect(await sentURL(transport) == "/api/v1/study/studyblocks/?scheduled_date=2026-03-07")
    }

    @Test func reviewIsTheDaysOnlyReview() async throws {
        let (api, _) = client([.success(.init(status: 200, body: try Fixture.data("stats_review_list")))])
        #expect(try await api.review(on: day)?.energy == 2)
    }

    @Test func noReviewYetIsNil() async throws {
        let empty = #"{"count":0,"next":null,"previous":null,"results":[]}"#
        let (api, _) = client([FakeHTTPTransport.json(200, empty)])
        #expect(try await api.review(on: day) == nil)
    }

    @Test func profileIsFetched() async throws {
        let (api, transport) = client([.success(.init(status: 200, body: try Fixture.data("profile")))])
        #expect(try await api.profile().pomodoroWorkMinutes == 25)
        #expect(await transport.sent.first?.url?.path() == "/api/v1/auth/profile/")
    }
}
