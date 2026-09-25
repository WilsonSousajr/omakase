import Foundation

public struct OutboxRequest: Sendable, Equatable {
    public let method: String
    public let path: String
    public let body: Data?
    public let idempotencyKey: String

    public init(method: String, path: String, body: Data?, idempotencyKey: String) {
        (self.method, self.path, self.body, self.idempotencyKey) = (method, path, body, idempotencyKey)
    }
}

public struct OutboxResponse: Sendable, Equatable {
    public let status: Int
    public let body: Data

    public init(status: Int, body: Data) { (self.status, self.body) = (status, body) }
}

public protocol APIClient: Sendable {
    func signIn(googleIDToken: String) async throws -> UserDTO
    func me() async throws -> UserDTO
    func tasks(on day: APIDay) async throws -> [TaskDTO]
    /// Any HTTP status is a response; only a missing answer throws.
    func send(_ request: OutboxRequest) async throws -> OutboxResponse
    func signOut() async
    /// Whether tokens are stored - answerable offline, unlike `me()`.
    func hasStoredSession() async -> Bool
}

/// The REST client. Owns tokens and refresh-on-401: refresh once, retry once,
/// otherwise `APIError.signedOut` and the tokens are cleared.
public actor OmakaseAPIClient: APIClient {
    private let baseURL: URL
    private let transport: any HTTPTransport
    private let tokens: any TokenStore

    public init(baseURL: URL, transport: any HTTPTransport, tokens: any TokenStore) {
        (self.baseURL, self.transport, self.tokens) = (baseURL, transport, tokens)
    }

    public func signIn(googleIDToken: String) async throws -> UserDTO {
        let body = try OmakaseJSON.encoder.encode(["credential": googleIDToken])
        let reply = try await raw("POST", "/api/v1/auth/google/", body: body, auth: false)
        let pair: TokenPairDTO = try decode(reply)
        try await tokens.save(StoredTokens(access: pair.access, refresh: pair.refresh))
        return pair.user
    }

    public func me() async throws -> UserDTO {
        try decode(try await authorized("GET", "/api/v1/auth/me/"))
    }

    public func tasks(on day: APIDay) async throws -> [TaskDTO] {
        var results: [TaskDTO] = []
        var path: String? = "/api/v1/tasks/today/?date=\(day.string)"
        while let next = path {
            let page: Page<TaskDTO> = try decode(try await authorized("GET", next))
            results += page.results
            path = page.next.map { $0.path() + ($0.query().map { "?\($0)" } ?? "") }
        }
        return results
    }

    public func send(_ request: OutboxRequest) async throws -> OutboxResponse {
        let reply = try await authorized(
            request.method, request.path, body: request.body, headers: ["Idempotency-Key": request.idempotencyKey])
        return OutboxResponse(status: reply.status, body: reply.data)
    }

    public func signOut() async { await tokens.clear() }

    public func hasStoredSession() async -> Bool { await tokens.load() != nil }

    private struct Reply {
        let data: Data
        let status: Int
    }

    private func authorized(
        _ method: String, _ path: String, body: Data? = nil, headers: [String: String] = [:]
    ) async throws -> Reply {
        let first = try await raw(method, path, body: body, headers: headers, auth: true)
        guard first.status == 401 else { return first }
        try await refresh()
        let retry = try await raw(method, path, body: body, headers: headers, auth: true)
        guard retry.status != 401 else {
            await tokens.clear()
            throw APIError.signedOut
        }
        return retry
    }

    private func refresh() async throws {
        guard var stored = await tokens.load() else { throw APIError.signedOut }
        let body = try OmakaseJSON.encoder.encode(["refresh": stored.refresh])
        let reply = try await raw("POST", "/api/v1/auth/token/refresh/", body: body, auth: false)
        guard reply.status == 200, let token = try? OmakaseJSON.decoder.decode(AccessTokenDTO.self, from: reply.data)
        else {
            await tokens.clear()
            throw APIError.signedOut
        }
        stored.access = token.access
        try await tokens.save(stored)
    }

    private func raw(
        _ method: String, _ path: String, body: Data? = nil, headers: [String: String] = [:], auth: Bool
    ) async throws -> Reply {
        let request = try await makeRequest(method, path, body: body, headers: headers, auth: auth)
        do {
            let (data, response) = try await transport.send(request)
            return Reply(data: data, status: response.statusCode)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
    }

    private func makeRequest(
        _ method: String, _ path: String, body: Data?, headers: [String: String], auth: Bool
    ) async throws -> URLRequest {
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else {
            throw APIError.transport("path \(path.debugDescription) is not a URL relative to \(baseURL)")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (field, value) in headers { request.setValue(value, forHTTPHeaderField: field) }
        if auth, let access = await tokens.load()?.access {
            request.setValue("Bearer \(access)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func decode<T: Decodable>(_ reply: Reply) throws -> T {
        guard (200..<300).contains(reply.status) else {
            let detail = (try? JSONDecoder().decode([String: String].self, from: reply.data))?["detail"]
            throw APIError.http(status: reply.status, detail: detail ?? "HTTP \(reply.status)")
        }
        do {
            return try OmakaseJSON.decoder.decode(T.self, from: reply.data)
        } catch {
            throw APIError.decoding("\(T.self): \(error)")
        }
    }
}
