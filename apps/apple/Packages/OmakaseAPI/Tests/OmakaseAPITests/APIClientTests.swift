import Foundation
import Testing

@testable import OmakaseAPI

struct APIClientTests {
    private let base = URL(string: "http://localhost:8000")!

    private func client(
        _ transport: FakeHTTPTransport, tokens: StoredTokens? = .init(access: "a1", refresh: "r1")
    ) -> (OmakaseAPIClient, InMemoryTokenStore) {
        let store = InMemoryTokenStore(tokens)
        return (OmakaseAPIClient(baseURL: base, transport: transport, tokens: store), store)
    }

    @Test func signInStoresThePairAndReturnsTheUser() async throws {
        let transport = FakeHTTPTransport([.success(.init(status: 200, body: try Fixture.data("auth_google")))])
        let (api, store) = client(transport, tokens: nil)
        let user = try await api.signIn(googleIDToken: "google-id-token")
        #expect(user.email == "ada@example.com")
        #expect(await store.load() != nil)
        let request = try #require(await transport.sent.first)
        #expect(request.url?.path() == "/api/v1/auth/google/")
        #expect(String(bytes: request.httpBody ?? Data(), encoding: .utf8) == #"{"credential":"google-id-token"}"#)
    }

    @Test func todaySendsTheClientsDayAndFollowsPages() async throws {
        let transport = FakeHTTPTransport([.success(.init(status: 200, body: try Fixture.data("tasks_today")))])
        let (api, _) = client(transport)
        let tasks = try await api.tasks(on: APIDay(string: "2026-03-07")!)
        #expect(tasks.count == 1)
        let request = try #require(await transport.sent.first)
        #expect(request.url?.query() == "date=2026-03-07")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer a1")
    }

    @Test func a401RefreshesOnceAndRetries() async throws {
        let transport = FakeHTTPTransport([
            FakeHTTPTransport.json(401, #"{"detail":"expired"}"#),
            .success(.init(status: 200, body: try Fixture.data("token_refresh"))),
            .success(.init(status: 200, body: try Fixture.data("auth_me"))),
        ])
        let (api, store) = client(transport)
        _ = try await api.me()
        let paths = await transport.sent.map { $0.url!.path() }
        #expect(paths == ["/api/v1/auth/me/", "/api/v1/auth/token/refresh/", "/api/v1/auth/me/"])
        #expect(await store.load()?.refresh == "r1")
        #expect(await store.load()?.access != "a1")
    }

    @Test func aFailedRefreshSignsOut() async throws {
        let transport = FakeHTTPTransport([FakeHTTPTransport.json(401, "{}"), FakeHTTPTransport.json(401, "{}")])
        let (api, store) = client(transport)
        await #expect(throws: APIError.signedOut) { try await api.me() }
        #expect(await store.load() == nil)
    }

    @Test func outboxRequestsCarryTheIdempotencyKeyAndReturnAnyStatus() async throws {
        let transport = FakeHTTPTransport([FakeHTTPTransport.json(400, #"{"title":["required"]}"#)])
        let (api, _) = client(transport)
        let response = try await api.send(
            OutboxRequest(method: "POST", path: "/api/v1/tasks/", body: Data("{}".utf8), idempotencyKey: "k-1"))
        #expect(response.status == 400)
        #expect(await transport.sent.first?.value(forHTTPHeaderField: "Idempotency-Key") == "k-1")
    }

    @Test func aNetworkFailureIsATransportError() async {
        let transport = FakeHTTPTransport([.failure(URLError(.notConnectedToInternet))])
        let (api, _) = client(transport)
        await #expect(throws: APIError.self) { try await api.me() }
    }
}
