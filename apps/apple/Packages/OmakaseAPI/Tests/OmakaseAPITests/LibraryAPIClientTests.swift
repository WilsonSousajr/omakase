import Foundation
import Testing

@testable import OmakaseAPI

/// The library's reads (#224) and a sign-out that revokes the refresh token
/// on the server before forgetting it (#223).
struct LibraryAPIClientTests {
    private let base = URL(string: "http://localhost:8000")!

    private func client(
        _ replies: [Result<FakeHTTPTransport.Reply, URLError>]
    ) -> (OmakaseAPIClient, FakeHTTPTransport, InMemoryTokenStore) {
        let transport = FakeHTTPTransport(replies)
        let tokens = InMemoryTokenStore(.init(access: "a1", refresh: "r1"))
        return (OmakaseAPIClient(baseURL: base, transport: transport, tokens: tokens), transport, tokens)
    }

    private func paths(_ transport: FakeHTTPTransport) async -> [String] {
        await transport.sent.compactMap { request in request.url.map { $0.path() + "?" + ($0.query() ?? "") } }
    }

    private func ok(_ fixture: String) throws -> Result<FakeHTTPTransport.Reply, URLError> {
        .success(.init(status: 200, body: try Fixture.data(fixture)))
    }

    @Test func readsTheLibraryListsFromTheirEndpoints() async throws {
        let (api, transport, _) = client([
            try ok("workspaces_list"), try ok("projects_list"), try ok("study_semesters_list"),
            try ok("study_disciplines_list"), try ok("study_classschedules_list"), try ok("study_holidays_list"),
            try ok("tasks_unscheduled"),
        ])
        let counts = [
            try await api.workspaces().count, try await api.projects().count, try await api.semesters().count,
            try await api.disciplines().count, try await api.classSchedules().count, try await api.holidays().count,
            try await api.unscheduledTasks().count,
        ]
        #expect(counts == [1, 1, 1, 1, 1, 1, 1])
        #expect(
            await paths(transport) == [
                "/api/v1/workspaces/?", "/api/v1/projects/?", "/api/v1/study/semesters/?",
                "/api/v1/study/disciplines/?", "/api/v1/study/classschedules/?", "/api/v1/study/holidays/?",
                "/api/v1/tasks/?unscheduled=true",
            ])
    }

    @Test func signingOutRevokesTheRefreshTokenThenForgetsBoth() async throws {
        let (api, transport, tokens) = client([.success(.init(status: 205, body: Data()))])
        await api.signOut()
        let sent = try #require(await transport.sent.first)
        #expect(sent.httpMethod == "POST" && sent.url?.path() == "/api/v1/auth/logout/")
        let body = try JSONSerialization.jsonObject(with: sent.httpBody ?? Data()) as? [String: String]
        #expect(body == ["refresh": "r1"])
        #expect(await tokens.load() == nil)
    }

    @Test func signingOutOfflineStillForgetsTheTokens() async {
        let (api, _, tokens) = client([.failure(URLError(.notConnectedToInternet))])
        await api.signOut()
        #expect(await tokens.load() == nil)
    }
}
