import Foundation
import Testing

@testable import OmakaseAPI

/// A named fake that counts how often the wrapped store is really read.
actor CountingTokenStore: TokenStore {
    private var tokens: StoredTokens?
    private(set) var loads = 0
    init(_ tokens: StoredTokens?) { self.tokens = tokens }
    func load() -> StoredTokens? {
        loads += 1
        return tokens
    }
    func save(_ tokens: StoredTokens) { self.tokens = tokens }
    func clear() { tokens = nil }
}

struct CachingTokenStoreTests {
    let stored = StoredTokens(access: "a1", refresh: "r1")

    @Test func theKeychainIsReadOncePerLaunchIssue168() async {
        // Every API request loads the tokens; each Keychain read of an
        // ad-hoc-signed build prompts, so the prompt never went away.
        let keychain = CountingTokenStore(stored)
        let store = CachingTokenStore(wrapping: keychain)
        for _ in 0..<5 { #expect(await store.load() == stored) }
        #expect(await keychain.loads == 1)
    }

    @Test func aSaveIsWrittenThroughAndServedFromMemory() async throws {
        let keychain = CountingTokenStore(nil)
        let store = CachingTokenStore(wrapping: keychain)
        let fresh = StoredTokens(access: "a2", refresh: "r2")
        try await store.save(fresh)
        #expect(await store.load() == fresh)
        #expect(await keychain.load() == fresh)
        #expect(await keychain.loads == 1)  // only the line above
    }

    @Test func clearingForgetsInMemoryAndInTheKeychain() async {
        let keychain = CountingTokenStore(stored)
        let store = CachingTokenStore(wrapping: keychain)
        _ = await store.load()
        await store.clear()
        #expect(await store.load() == nil)
        #expect(await keychain.load() == nil)
    }

    @Test func aMissingTokenIsAlsoRememberedUntilASave() async {
        let keychain = CountingTokenStore(nil)
        let store = CachingTokenStore(wrapping: keychain)
        _ = await store.load()
        _ = await store.load()
        #expect(await keychain.loads == 1)
    }
}
