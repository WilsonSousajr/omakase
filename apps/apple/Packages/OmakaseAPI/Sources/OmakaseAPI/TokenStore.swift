import Foundation
import Security

public struct StoredTokens: Sendable, Codable, Equatable {
    public var access: String
    public var refresh: String
    public init(access: String, refresh: String) { (self.access, self.refresh) = (access, refresh) }
}

public protocol TokenStore: Sendable {
    func load() async -> StoredTokens?
    func save(_ tokens: StoredTokens) async throws
    func clear() async
}

/// Tokens in the login Keychain, as one generic-password item (spec: no
/// localStorage-style storage for credentials).
public struct KeychainTokenStore: TokenStore {
    private let service: String
    public init(service: String = "dev.omakase.mac.tokens") { self.service = service }

    public func load() async -> StoredTokens? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return try? JSONDecoder().decode(StoredTokens.self, from: data)
    }

    public func save(_ tokens: StoredTokens) async throws {
        await clear()
        var item = baseQuery
        item[kSecValueData as String] = try JSONEncoder().encode(tokens)
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw APIError.transport("Keychain save failed with OSStatus \(status)") }
    }

    public func clear() async { SecItemDelete(baseQuery as CFDictionary) }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
            kSecAttrAccount as String: "jwt",
        ]
    }
}

/// Reads the wrapped store (the Keychain) once per launch and keeps the
/// tokens in memory; saves and clears write through. Every API request loads
/// the tokens, and each Keychain read by a newly built, ad-hoc-signed app
/// raises a permission prompt, so reading per request prompted endlessly (#168).
///
///     let tokens = CachingTokenStore(wrapping: KeychainTokenStore())
public actor CachingTokenStore: TokenStore {
    private let wrapped: any TokenStore
    /// nil until the first load; then what the wrapped store holds, even if that is nothing.
    private var cached: StoredTokens??

    public init(wrapping wrapped: any TokenStore) { self.wrapped = wrapped }

    public func load() async -> StoredTokens? {
        if let cached { return cached }
        let tokens = await wrapped.load()
        cached = .some(tokens)
        return tokens
    }

    public func save(_ tokens: StoredTokens) async throws {
        try await wrapped.save(tokens)
        cached = .some(tokens)
    }

    public func clear() async {
        await wrapped.clear()
        cached = .some(nil)
    }
}

public actor InMemoryTokenStore: TokenStore {
    private var tokens: StoredTokens?
    public init(_ tokens: StoredTokens? = nil) { self.tokens = tokens }
    public func load() -> StoredTokens? { tokens }
    public func save(_ tokens: StoredTokens) { self.tokens = tokens }
    public func clear() { tokens = nil }
}
