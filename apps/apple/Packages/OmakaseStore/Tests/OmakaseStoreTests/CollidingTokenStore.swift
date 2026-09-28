import Foundation
import OmakaseAPI

/// A named fake `TokenStore` for #276: models `KeychainTokenStore`'s
/// unguarded delete-then-add (`clear()` then `SecItemAdd`, not one
/// transaction) - the first `save()` in flight wins, and every other
/// concurrent `save()` collides with it, exactly as `SecItemAdd` returning
/// `errSecDuplicateItem` would. The check-and-increment has no `await` in
/// it, so which caller "wins" is whichever is scheduled first, but exactly
/// one always wins: unlike the transport's wave gate, this needs no
/// ordering help, because "first save succeeds, every other throws" holds
/// regardless of how the callers interleave.
actor CollidingTokenStore: TokenStore {
    private var stored: StoredTokens?
    private var saveCount = 0

    init(_ tokens: StoredTokens? = nil) { stored = tokens }

    func load() async -> StoredTokens? { stored }

    func save(_ tokens: StoredTokens) async throws {
        saveCount += 1
        guard saveCount == 1 else { throw APIError.transport("Keychain save failed with OSStatus -25299") }
        stored = tokens
    }

    func clear() async { stored = nil }
}
