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

public actor InMemoryTokenStore: TokenStore {
    private var tokens: StoredTokens?
    public init(_ tokens: StoredTokens? = nil) { self.tokens = tokens }
    public func load() -> StoredTokens? { tokens }
    public func save(_ tokens: StoredTokens) { self.tokens = tokens }
    public func clear() { tokens = nil }
}
