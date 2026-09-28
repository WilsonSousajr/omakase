import Foundation
import Testing

@testable import OmakaseAPI

/// The visible week's reads (#200): blocks and classes by day, sessions by instant.
struct RangeAPIClientTests {
    private let base = URL(string: "http://localhost:8000")!
    private let monday = APIDay(string: "2026-09-21")!
    private let sunday = APIDay(string: "2026-09-27")!

    private func client(
        _ replies: [Result<FakeHTTPTransport.Reply, URLError>]
    ) -> (OmakaseAPIClient, FakeHTTPTransport) {
        let transport = FakeHTTPTransport(replies)
        let tokens = InMemoryTokenStore(.init(access: "a1", refresh: "r1"))
        return (OmakaseAPIClient(baseURL: base, transport: transport, tokens: tokens), transport)
    }

    private func sentURLs(_ transport: FakeHTTPTransport) async -> [String] {
        await transport.sent.compactMap { request in request.url.map { $0.path() + "?" + ($0.query() ?? "") } }
    }

    @Test func timeBlocksSendTheRange() async throws {
        let (api, transport) = client([.success(.init(status: 200, body: try Fixture.data("timeblocks_day")))])
        #expect(try await api.timeBlocks(from: monday, to: sunday).count == 1)
        #expect(await sentURLs(transport) == ["/api/v1/timeblocks/?date_from=2026-09-21&date_to=2026-09-27"])
    }

    @Test func timeBlocksFollowEveryPage() async throws {
        var first = try JSONSerialization.jsonObject(with: Fixture.data("timeblocks_day")) as? [String: Any] ?? [:]
        first["next"] = "http://localhost:8000/api/v1/timeblocks/?date_from=2026-09-21&date_to=2026-09-27&page=2"
        let firstPage = try JSONSerialization.data(withJSONObject: first)
        let (api, transport) = client([
            .success(.init(status: 200, body: firstPage)),
            .success(.init(status: 200, body: try Fixture.data("timeblocks_day"))),
        ])
        #expect(try await api.timeBlocks(from: monday, to: sunday).count == 2)
        #expect(await sentURLs(transport).last == "/api/v1/timeblocks/?date_from=2026-09-21&date_to=2026-09-27&page=2")
    }

    @Test func classOccurrencesAreAPlainListForTheRange() async throws {
        let (api, transport) = client([FakeHTTPTransport.json(200, "[\(ClassOccurrenceSample.json)]")])
        let occurrences = try await api.classOccurrences(from: monday, to: sunday)
        #expect(occurrences.map(\.id) == [ClassOccurrenceSample.id])
        let expected = "/api/v1/study/class-occurrences/?date_from=2026-09-21&date_to=2026-09-27"
        #expect(await sentURLs(transport) == [expected])
    }

    @Test func sessionBoundsAreSentAsUTCInstantsWithZ() async throws {
        // A "+03:00" offset would reach Django as " 03:00": a `+` in a query is a space.
        let (api, transport) = client([.success(.init(status: 200, body: try Fixture.data("pomodoro_sessions_range")))])
        let after = Date(timeIntervalSince1970: 1_789_959_600)  // 2026-09-21T03:00:00Z
        let sessions = try await api.sessions(startedAfter: after, startedBefore: after.addingTimeInterval(7 * 86_400))
        #expect(sessions.count == 1)
        #expect(
            await sentURLs(transport) == [
                "/api/v1/pomodoro/sessions/?started_after=2026-09-21T03:00:00Z&started_before=2026-09-28T03:00:00Z"
            ])
    }

    @Test func sessionsDecodeAsListItems() async throws {
        let (api, _) = client([.success(.init(status: 200, body: try Fixture.data("pomodoro_sessions_range")))])
        let now = Date(timeIntervalSince1970: 1_789_959_600)
        let session = try #require(try await api.sessions(startedAfter: now, startedBefore: now).first)
        #expect(session.sessionType == "focus" && session.timeBlock != nil && session.endedAt != nil)
    }
}
