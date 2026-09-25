import Foundation
import OmakaseAPI

/// Scripted API for Store tests: today's tasks per day, and one outcome per
/// outbox send, in order. Records every outbox request it receives.
actor FakeAPIClient: APIClient {
    enum SendOutcome: Sendable {
        case reply(Int, String)
        case offline
        case signedOut
    }

    private var tasksByDay: [String: [TaskDTO]] = [:]
    private var outcomes: [SendOutcome] = []
    private(set) var sentRequests: [OutboxRequest] = []

    func setTasks(_ tasks: [TaskDTO], on day: String) { tasksByDay[day] = tasks }
    func script(_ outcomes: [SendOutcome]) { self.outcomes = outcomes }

    func signIn(googleIDToken: String) async throws -> UserDTO { throw APIError.signedOut }
    func me() async throws -> UserDTO { throw APIError.signedOut }
    func signOut() async {}
    func hasStoredSession() async -> Bool { true }

    func tasks(on day: APIDay) async throws -> [TaskDTO] { tasksByDay[day.string] ?? [] }

    func send(_ request: OutboxRequest) async throws -> OutboxResponse {
        sentRequests.append(request)
        switch outcomes.isEmpty ? .offline : outcomes.removeFirst() {
        case .reply(let status, let body): return OutboxResponse(status: status, body: Data(body.utf8))
        case .offline: throw APIError.transport("offline")
        case .signedOut: throw APIError.signedOut
        }
    }
}

extension TaskDTO {
    /// A task as the server would send it, for tests.
    static func make(
        id: UUID = UUID(), title: String = "Task", day: String? = "2026-03-07", completed: Bool = false
    ) throws -> TaskDTO {
        let json = """
            {"id":"\(id)","title":"\(title)","description":"","priority":"medium","area":"work",
             "kanban_status":"todo","project":null,"discipline":null,"tags":[],
             "scheduled_date":\(day.map { "\"\($0)\"" } ?? "null"),"due_date":null,"estimated_minutes":null,
             "actual_minutes":0,"kanban_order":0,"is_completed":\(completed),"completed_at":null,
             "created_at":"2026-03-07T12:00:00Z","updated_at":"2026-03-07T12:00:00Z"}
            """
        return try OmakaseJSON.decoder.decode(TaskDTO.self, from: Data(json.utf8))
    }
}
