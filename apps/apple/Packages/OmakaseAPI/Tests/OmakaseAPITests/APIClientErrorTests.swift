import Foundation
import Testing

@testable import OmakaseAPI

struct APIClientErrorTests {
    private let base = URL(string: "http://localhost:8000")!

    private func client(_ transport: FakeHTTPTransport) -> (OmakaseAPIClient, InMemoryTokenStore) {
        let store = InMemoryTokenStore(StoredTokens(access: "a1", refresh: "r1"))
        return (OmakaseAPIClient(baseURL: base, transport: transport, tokens: store), store)
    }

    @Test func aNon2xxAnswerCarriesTheServersDetail() async {
        let (api, _) = client(FakeHTTPTransport([FakeHTTPTransport.json(403, #"{"detail":"not yours"}"#)]))
        await #expect(throws: APIError.http(status: 403, detail: "not yours")) { try await api.me() }
    }

    @Test func aBodyThatIsNotTheContractIsADecodingError() async {
        let (api, _) = client(FakeHTTPTransport([FakeHTTPTransport.json(200, #"{"unexpected":true}"#)]))
        await #expect {
            try await api.me()
        } throws: { error in
            guard case .decoding(let reason) = error as? APIError else { return false }
            return reason.hasPrefix("UserDTO")
        }
    }

    @Test func todayFollowsTheNextPage() async throws {
        let page = try Fixture.data("tasks_today")
        var first = try JSONSerialization.jsonObject(with: page) as? [String: Any] ?? [:]
        first["next"] = "http://localhost:8000/api/v1/tasks/today/?date=2026-03-07&page=2"
        let transport = FakeHTTPTransport([
            .success(.init(status: 200, body: try JSONSerialization.data(withJSONObject: first))),
            .success(.init(status: 200, body: page)),
        ])
        let (api, _) = client(transport)
        #expect(try await api.tasks(on: APIDay(string: "2026-03-07")!).count == 2)
        #expect(await transport.sent.last?.url?.query() == "date=2026-03-07&page=2")
    }

    @Test func signOutForgetsTheTokens() async {
        let (api, store) = client(FakeHTTPTransport([]))
        await api.signOut()
        #expect(await store.load() == nil)
    }
}

struct KeychainTokenStoreTests {
    @Test func savesLoadsAndClearsUnderItsOwnService() async throws {
        // A unique service per run: never touches the app's real item.
        let store = KeychainTokenStore(service: "dev.omakase.tests.\(UUID().uuidString)")
        defer { Task { await store.clear() } }
        #expect(await store.load() == nil)
        try await store.save(StoredTokens(access: "a", refresh: "r"))
        try await store.save(StoredTokens(access: "a2", refresh: "r"))
        #expect(await store.load() == StoredTokens(access: "a2", refresh: "r"))
        await store.clear()
        #expect(await store.load() == nil)
    }
}
