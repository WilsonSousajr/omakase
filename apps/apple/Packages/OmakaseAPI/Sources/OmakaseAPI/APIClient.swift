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
    func carriedOver(on day: APIDay) async throws -> [TaskDTO]
    /// The tasks on `from` through `to` with each series' computed occurrences (#124); at most 62 days.
    func occurrences(from first: APIDay, to last: APIDay) async throws -> [TaskDTO]
    func timeBlocks(on day: APIDay) async throws -> [TimeBlockDTO]
    func studyBlocks(on day: APIDay) async throws -> [StudyBlockDTO]
    /// Every block dated `from` through `to`, both inclusive (#200).
    func timeBlocks(from first: APIDay, to last: APIDay) async throws -> [TimeBlockDTO]
    /// The weekly classes that fall on `from` through `to`; the server caps the range at 90 days.
    func classOccurrences(from first: APIDay, to last: APIDay) async throws -> [ClassOccurrenceDTO]
    /// Sessions started at or after `startedAfter` and before `startedBefore`.
    func sessions(startedAfter: Date, startedBefore: Date) async throws -> [PomodoroSessionDTO]
    /// The day's one review, or nil before one exists.
    func review(on day: APIDay) async throws -> DailyReviewDTO?
    func profile() async throws -> ProfileDTO
    /// The day's planned minutes against the goal, summed on the server (#128).
    func workload(on day: APIDay) async throws -> WorkloadDTO
    /// The library (#224): every page, scoped to the user on the server.
    func workspaces() async throws -> [WorkspaceDTO]
    func projects() async throws -> [ProjectDTO]
    func semesters() async throws -> [SemesterDTO]
    func disciplines() async throws -> [DisciplineDTO]
    func classSchedules() async throws -> [ClassScheduleDTO]
    func holidays() async throws -> [HolidayDTO]
    /// The Inbox: tasks with no date (#223).
    func unscheduledTasks() async throws -> [TaskDTO]
    /// Any HTTP status is a response; only a missing answer throws.
    func send(_ request: OutboxRequest) async throws -> OutboxResponse
    /// Revokes the refresh token on the server when it can, then forgets both.
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

    /// The day's rows and its computed occurrences (`isVirtual`, `id` nil, #206).
    public func tasks(on day: APIDay) async throws -> [TaskDTO] {
        try await allPages("/api/v1/tasks/today/?date=\(day.string)")
    }

    public func carriedOver(on day: APIDay) async throws -> [TaskDTO] {
        // Not paginated: the action returns a plain list (backend/tasks/views.py).
        try decode(try await authorized("GET", "/api/v1/tasks/carried-over/?date=\(day.string)"))
    }

    public func occurrences(from first: APIDay, to last: APIDay) async throws -> [TaskDTO] {
        // Not paginated: a plain list, as class-occurrences/ is (backend/tasks/views.py).
        let path = "/api/v1/tasks/occurrences/?date_from=\(first.string)&date_to=\(last.string)"
        return try decode(try await authorized("GET", path))
    }

    public func timeBlocks(on day: APIDay) async throws -> [TimeBlockDTO] {
        try await allPages("/api/v1/timeblocks/?date=\(day.string)")
    }

    public func studyBlocks(on day: APIDay) async throws -> [StudyBlockDTO] {
        try await allPages("/api/v1/study/studyblocks/?scheduled_date=\(day.string)")
    }

    public func timeBlocks(from first: APIDay, to last: APIDay) async throws -> [TimeBlockDTO] {
        try await allPages("/api/v1/timeblocks/?date_from=\(first.string)&date_to=\(last.string)")
    }

    public func classOccurrences(from first: APIDay, to last: APIDay) async throws -> [ClassOccurrenceDTO] {
        // Not paginated: the view returns a plain list (backend/study/views.py).
        let path = "/api/v1/study/class-occurrences/?date_from=\(first.string)&date_to=\(last.string)"
        return try decode(try await authorized("GET", path))
    }

    /// The bounds go out in UTC with "Z": a "+hh:mm" offset would reach Django
    /// as a space, because a query string reads `+` as one (#200).
    public func sessions(startedAfter: Date, startedBefore: Date) async throws -> [PomodoroSessionDTO] {
        let formatter = ISO8601DateFormatter()
        let (after, before) = (formatter.string(from: startedAfter), formatter.string(from: startedBefore))
        return try await allPages("/api/v1/pomodoro/sessions/?started_after=\(after)&started_before=\(before)")
    }

    public func review(on day: APIDay) async throws -> DailyReviewDTO? {
        let reviews: [DailyReviewDTO] = try await allPages("/api/v1/stats/reviews/?date=\(day.string)")
        return reviews.first
    }

    public func profile() async throws -> ProfileDTO {
        try decode(try await authorized("GET", "/api/v1/auth/profile/"))
    }

    public func workload(on day: APIDay) async throws -> WorkloadDTO {
        try decode(try await authorized("GET", "/api/v1/stats/workload/?date=\(day.string)"))
    }

    /// Follows DRF's `next` links until the last page.
    private func allPages<Item: Sendable & Codable & Equatable>(_ first: String) async throws -> [Item] {
        var results: [Item] = []
        var path: String? = first
        while let next = path {
            let page: Page<Item> = try decode(try await authorized("GET", next))
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

    public func workspaces() async throws -> [WorkspaceDTO] { try await allPages("/api/v1/workspaces/") }

    public func projects() async throws -> [ProjectDTO] { try await allPages("/api/v1/projects/") }

    public func semesters() async throws -> [SemesterDTO] { try await allPages("/api/v1/study/semesters/") }

    public func disciplines() async throws -> [DisciplineDTO] { try await allPages("/api/v1/study/disciplines/") }

    public func classSchedules() async throws -> [ClassScheduleDTO] {
        try await allPages("/api/v1/study/classschedules/")
    }

    public func holidays() async throws -> [HolidayDTO] { try await allPages("/api/v1/study/holidays/") }

    public func unscheduledTasks() async throws -> [TaskDTO] {
        try await allPages("/api/v1/tasks/?unscheduled=true")
    }

    /// Best effort: offline, or with the token already gone, the Keychain is
    /// still cleared, and a stolen copy expires within 7 days (#223).
    public func signOut() async {
        await revokeRefreshToken()
        await tokens.clear()
    }

    private func revokeRefreshToken() async {
        guard let refresh = await tokens.load()?.refresh else { return }
        guard let body = try? OmakaseJSON.encoder.encode(["refresh": refresh]) else { return }
        _ = try? await authorized("POST", "/api/v1/auth/logout/", body: body)
    }

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
