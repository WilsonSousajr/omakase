import Foundation
import Testing

@testable import OmakaseAPI

/// A place's open tasks (spec §5): the request each query sends, and that a
/// plain task-list page (`tasks_unscheduled`'s shape) decodes and follows its pages.
struct PlaceTasksAPIClientTests {
    private let base = URL(string: "http://localhost:8000")!
    private let projectID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
    private let disciplineID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!

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

    private func ok() throws -> Result<FakeHTTPTransport.Reply, URLError> {
        .success(.init(status: 200, body: try Fixture.data("tasks_unscheduled")))
    }

    @Test func aProjectSendsItsIDAndIsCompletedFalse() async throws {
        let (api, transport) = client([try ok()])
        #expect(try await api.openTasks(.project(projectID)).count == 1)
        let expected = "/api/v1/tasks/?project=\(projectID.uuidString)&is_completed=false"
        #expect(await sentURLs(transport) == [expected])
    }

    @Test func aDisciplineSendsItsID() async throws {
        let (api, transport) = client([try ok()])
        _ = try await api.openTasks(.discipline(disciplineID))
        let expected = "/api/v1/tasks/?discipline=\(disciplineID.uuidString)&is_completed=false"
        #expect(await sentURLs(transport) == [expected])
    }

    @Test func lifeSendsAreaPersonal() async throws {
        let (api, transport) = client([try ok()])
        _ = try await api.openTasks(.area("personal"))
        #expect(await sentURLs(transport) == ["/api/v1/tasks/?area=personal&is_completed=false"])
    }

    @Test func openTasksFollowEveryPage() async throws {
        var first = try JSONSerialization.jsonObject(with: Fixture.data("tasks_unscheduled")) as? [String: Any] ?? [:]
        first["next"] = "http://localhost:8000/api/v1/tasks/?project=\(projectID.uuidString)&is_completed=false&page=2"
        let firstPage = try JSONSerialization.data(withJSONObject: first)
        let (api, transport) = client([.success(.init(status: 200, body: firstPage)), try ok()])
        #expect(try await api.openTasks(.project(projectID)).count == 2)
        #expect(await sentURLs(transport).last?.contains("page=2") == true)
    }
}
