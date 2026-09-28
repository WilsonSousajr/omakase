import Foundation
import Testing

@testable import OmakaseAPI

/// #276: launching with an expired access token fired seven concurrent
/// requests, each refreshing on its own, and only one was ever retried - the
/// rest were lost, so the catch-up reported `.failed` and the window stayed
/// "Offline" until a later catch-up.
struct ConcurrentRefreshTests {
    private let base = URL(string: "http://localhost:8000")!

    @Test func concurrentExpiredRequestsRefreshOnceAndAllRetryIssue276() async throws {
        let wave = 7
        let transport = ConcurrentExpiredTokenTransport(meBody: try Fixture.data("auth_me"), wave: wave)
        let store = InMemoryTokenStore(StoredTokens(access: "a1", refresh: "r1"))
        let api = OmakaseAPIClient(baseURL: base, transport: transport, tokens: store)
        let results = try await withThrowingTaskGroup(of: UserDTO.self) { group in
            for _ in 0..<wave { group.addTask { try await api.me() } }
            var collected: [UserDTO] = []
            for try await user in group { collected.append(user) }
            return collected
        }
        #expect(results.count == wave)
        #expect(await transport.refreshCount == 1)
    }
}
