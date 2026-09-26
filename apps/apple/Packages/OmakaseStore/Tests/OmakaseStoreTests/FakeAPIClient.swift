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
    private var carriedByDay: [String: [TaskDTO]] = [:]
    private var blocksByDay: [String: [TimeBlockDTO]] = [:]
    private var studiesByDay: [String: [StudyBlockDTO]] = [:]
    private var reviewsByDay: [String: DailyReviewDTO] = [:]
    private var storedProfile: ProfileDTO?
    /// Every day a read asked for, in order: how DaySync's tests see one refresh use one day.
    private(set) var requestedDays: [String] = []

    func setTasks(_ tasks: [TaskDTO], on day: String) { tasksByDay[day] = tasks }
    func script(_ outcomes: [SendOutcome]) { self.outcomes = outcomes }
    func setCarriedOver(_ tasks: [TaskDTO], on day: String) { carriedByDay[day] = tasks }
    func setBlocks(_ blocks: [TimeBlockDTO], on day: String) { blocksByDay[day] = blocks }
    func setStudies(_ studies: [StudyBlockDTO], on day: String) { studiesByDay[day] = studies }
    func setReview(_ review: DailyReviewDTO?, on day: String) { reviewsByDay[day] = review }
    func setProfile(_ profile: ProfileDTO) { storedProfile = profile }

    func signIn(googleIDToken: String) async throws -> UserDTO { throw APIError.signedOut }
    func me() async throws -> UserDTO { throw APIError.signedOut }
    func signOut() async {}
    func hasStoredSession() async -> Bool { true }

    func tasks(on day: APIDay) async throws -> [TaskDTO] {
        note(day)
        return tasksByDay[day.string] ?? []
    }

    func carriedOver(on day: APIDay) async throws -> [TaskDTO] {
        note(day)
        return carriedByDay[day.string] ?? []
    }

    func timeBlocks(on day: APIDay) async throws -> [TimeBlockDTO] {
        note(day)
        return blocksByDay[day.string] ?? []
    }

    func studyBlocks(on day: APIDay) async throws -> [StudyBlockDTO] {
        note(day)
        return studiesByDay[day.string] ?? []
    }

    func review(on day: APIDay) async throws -> DailyReviewDTO? {
        note(day)
        return reviewsByDay[day.string]
    }

    func profile() async throws -> ProfileDTO {
        guard let storedProfile else { throw APIError.transport("no profile scripted") }
        return storedProfile
    }

    private func note(_ day: APIDay) { requestedDays.append(day.string) }

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
