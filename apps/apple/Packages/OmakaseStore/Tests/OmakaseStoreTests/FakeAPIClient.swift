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
    private var workloadsByDay: [String: WorkloadDTO] = [:]
    /// Every day a read asked for, in order: how DaySync's tests see one refresh use one day.
    private(set) var requestedDays: [String] = []
    /// Runs while `tasks(on:)` is "on the network": how a test makes a local
    /// write land in the middle of a refresh.
    private var duringTasksFetch: (@Sendable () async -> Void)?
    private var occurrences: [ClassOccurrenceDTO] = []
    private var taskOccurrences: [TaskDTO] = []
    private var sessionList: [PomodoroSessionDTO] = []
    /// Every range read, as "from..to" days or "after..before" instants: how RangeSync's tests see its bounds.
    private(set) var requestedRanges: [String] = []
    /// Runs while `timeBlocks(from:to:)` is "on the network".
    private var duringRangeFetch: (@Sendable () async -> Void)?
    /// The library's lists (#224), and whether reading them fails as offline.
    private var library = FakeLibrary()
    private var libraryOffline = false
    private(set) var signOutCount = 0

    func setTasks(_ tasks: [TaskDTO], on day: String) { tasksByDay[day] = tasks }
    func script(_ outcomes: [SendOutcome]) { self.outcomes = outcomes }
    func setCarriedOver(_ tasks: [TaskDTO], on day: String) { carriedByDay[day] = tasks }
    func setBlocks(_ blocks: [TimeBlockDTO], on day: String) { blocksByDay[day] = blocks }
    func setStudies(_ studies: [StudyBlockDTO], on day: String) { studiesByDay[day] = studies }
    func setReview(_ review: DailyReviewDTO?, on day: String) { reviewsByDay[day] = review }
    func setProfile(_ profile: ProfileDTO) { storedProfile = profile }
    func setWorkload(_ workload: WorkloadDTO, on day: String) { workloadsByDay[day] = workload }
    func setDuringTasksFetch(_ hook: @escaping @Sendable () async -> Void) { duringTasksFetch = hook }
    func setOccurrences(_ list: [ClassOccurrenceDTO]) { occurrences = list }
    func setTaskOccurrences(_ list: [TaskDTO]) { taskOccurrences = list }
    func setSessions(_ list: [PomodoroSessionDTO]) { sessionList = list }
    func setDuringRangeFetch(_ hook: @escaping @Sendable () async -> Void) { duringRangeFetch = hook }
    func setLibrary(_ lists: FakeLibrary) { library = lists }
    func setLibraryOffline(_ offline: Bool) { libraryOffline = offline }

    func signIn(googleIDToken: String) async throws -> UserDTO { throw APIError.signedOut }
    func me() async throws -> UserDTO { throw APIError.signedOut }
    func signOut() async { signOutCount += 1 }

    func workspaces() async throws -> [WorkspaceDTO] { try libraryRead(library.workspaces) }
    func projects() async throws -> [ProjectDTO] { try libraryRead(library.projects) }
    func semesters() async throws -> [SemesterDTO] { try libraryRead(library.semesters) }
    func disciplines() async throws -> [DisciplineDTO] { try libraryRead(library.disciplines) }
    func classSchedules() async throws -> [ClassScheduleDTO] { try libraryRead(library.schedules) }
    func holidays() async throws -> [HolidayDTO] { try libraryRead(library.holidays) }
    func unscheduledTasks() async throws -> [TaskDTO] { try libraryRead(library.inbox) }

    private func libraryRead<Item>(_ items: [Item]) throws -> [Item] {
        if libraryOffline { throw APIError.transport("offline") }
        return items
    }
    func hasStoredSession() async -> Bool { true }

    func tasks(on day: APIDay) async throws -> [TaskDTO] {
        note(day)
        await duringTasksFetch?()
        return tasksByDay[day.string] ?? []
    }

    func carriedOver(on day: APIDay) async throws -> [TaskDTO] {
        note(day)
        return carriedByDay[day.string] ?? []
    }

    func occurrences(from first: APIDay, to last: APIDay) async throws -> [TaskDTO] {
        requestedRanges.append("tasks \(first.string)..\(last.string)")
        return taskOccurrences.filter { ($0.scheduledDate ?? first) >= first && ($0.scheduledDate ?? last) <= last }
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

    func workload(on day: APIDay) async throws -> WorkloadDTO {
        note(day)
        return try workloadsByDay[day.string] ?? .make(day: day.string)
    }

    func timeBlocks(from first: APIDay, to last: APIDay) async throws -> [TimeBlockDTO] {
        requestedRanges.append("blocks \(first.string)..\(last.string)")
        await duringRangeFetch?()
        return blocksByDay.filter { $0.key >= first.string && $0.key <= last.string }.flatMap(\.value)
    }

    func classOccurrences(from first: APIDay, to last: APIDay) async throws -> [ClassOccurrenceDTO] {
        requestedRanges.append("classes \(first.string)..\(last.string)")
        return occurrences.filter { $0.date >= first && $0.date <= last }
    }

    func sessions(startedAfter: Date, startedBefore: Date) async throws -> [PomodoroSessionDTO] {
        let format = ISO8601DateFormatter()
        requestedRanges.append("sessions \(format.string(from: startedAfter))..\(format.string(from: startedBefore))")
        return sessionList.filter { $0.startedAt >= startedAfter && $0.startedAt < startedBefore }
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
    /// A task as the server would send it, for tests. `subtasks` nil leaves the key out, as the plain list does.
    static func make(
        id: UUID? = UUID(), title: String = "Task", day: String? = "2026-03-07", completed: Bool = false,
        subtasks: [(String, Bool)]? = nil, remindAt: String? = nil, description: String = "", series: UUID? = nil,
        area: String = "work", project: UUID? = nil, discipline: UUID? = nil
    ) throws -> TaskDTO {
        let json = """
            {"id":\(quoted(id)),"series":\(quoted(series)),"occurrence_date":\(series == nil ? "null" : quoted(day)),
             "is_skipped":false,"is_virtual":\(id == nil),"recurrence":null,
             "title":"\(title)","description":"\(description)","priority":"medium","area":"\(area)",
             "kanban_status":"todo","project":\(quoted(project)),"discipline":\(quoted(discipline)),"tags":[],
             "scheduled_date":\(day.map { "\"\($0)\"" } ?? "null"),"due_date":null,"estimated_minutes":null,
             "actual_minutes":0,"kanban_order":0,"is_completed":\(completed),"completed_at":null,
             "remind_at":\(remindAt.map { "\"\($0)\"" } ?? "null"),
             "created_at":"2026-03-07T12:00:00Z","updated_at":"2026-03-07T12:00:00Z"\(subtasksJSON(subtasks))}
            """
        return try OmakaseJSON.decoder.decode(TaskDTO.self, from: Data(json.utf8))
    }

    /// A computed occurrence of `series` on `day`: no id, as today/ sends it (#206).
    static func virtual(series: UUID, day: String, title: String = "Stand-up") throws -> TaskDTO {
        try make(id: nil, title: title, day: day, subtasks: [], series: series)
    }

    private static func quoted(_ value: (some CustomStringConvertible)?) -> String {
        value.map { "\"\($0)\"" } ?? "null"
    }

    private static func subtasksJSON(_ subtasks: [(String, Bool)]?) -> String {
        guard let subtasks else { return "" }
        let items = subtasks.enumerated().map { index, item in
            #"{"id":"\#(stableID(item.0))","title":"\#(item.0)","is_completed":\#(item.1),"order":\#(index)}"#
        }
        return #","subtasks":["# + items.joined(separator: ",") + "]"
    }

    /// The same title gives the same id within a test run, so a task re-sent with
    /// fewer subtasks keeps the survivors' ids, as the server would.
    private static func stableID(_ title: String) -> UUID {
        UUID(
            uuidString: String(
                format: "00000000-0000-4000-8000-%012llx", UInt64(bitPattern: Int64(title.hashValue)) & 0xFFFF_FFFF_FFFF
            ))!
    }
}

extension TimeBlockDTO {
    static func make(id: UUID = UUID(), day: String, task: UUID? = UUID()) throws -> TimeBlockDTO {
        let json = """
            {"id":"\(id)","task":\(task.map { "\"\($0)\"" } ?? "null"),"study_block":null,"date":"\(day)",
             "start_time":"09:00:00","end_time":"10:00:00","notes":"","session_rating":null}
            """
        return try OmakaseJSON.decoder.decode(TimeBlockDTO.self, from: Data(json.utf8))
    }
}

extension ClassOccurrenceDTO {
    static func make(
        schedule: UUID = UUID(), day: String, name: String = "Calculus", cancelled: Bool = false
    ) throws -> ClassOccurrenceDTO {
        let json = """
            {"id":"\(schedule)-\(day)","class_schedule_id":"\(schedule)","discipline_name":"\(name)",
             "discipline_color":"#3B82F6","class_type":"lecture","location":"Room 101","date":"\(day)",
             "start_time":"08:00:00","end_time":"09:40:00","week":2,"is_cancelled":\(cancelled)}
            """
        return try OmakaseJSON.decoder.decode(ClassOccurrenceDTO.self, from: Data(json.utf8))
    }
}

extension PomodoroSessionDTO {
    static func make(id: UUID = UUID(), startedAt: String, block: UUID? = nil) throws -> PomodoroSessionDTO {
        let json = """
            {"id":"\(id)","task":null,"time_block":\(block.map { "\"\($0)\"" } ?? "null"),"session_type":"focus",
             "duration_minutes":25,"started_at":"\(startedAt)","ended_at":null,"completed":false}
            """
        return try OmakaseJSON.decoder.decode(PomodoroSessionDTO.self, from: Data(json.utf8))
    }
}

extension DailyReviewDTO {
    static func make(day: String, energy: Int? = nil) throws -> DailyReviewDTO {
        let json = """
            {"id":"\(UUID())","date":"\(day)","productivity_rating":null,"win_of_the_day":"",
             "energy":\(energy.map(String.init) ?? "null"),"is_shutdown":false,"shutdown_at":null}
            """
        return try OmakaseJSON.decoder.decode(DailyReviewDTO.self, from: Data(json.utf8))
    }
}

extension ProfileDTO {
    static func make(blockReminderMinutes: Int? = 5, shutdownReminderTime: String? = nil) throws -> ProfileDTO {
        let json = """
            {"pomodoro_work_minutes":25,"pomodoro_short_break_minutes":5,"pomodoro_long_break_minutes":15,
             "pomodoros_before_long_break":4,"daily_work_goal_hours":"8.0","daily_study_goal_hours":"4.0",
             "block_reminder_minutes":\(blockReminderMinutes.map(String.init) ?? "null"),
             "shutdown_reminder_time":\(shutdownReminderTime.map { "\"\($0)\"" } ?? "null"),
             "timezone":"UTC","week_starts_on":"monday"}
            """
        return try OmakaseJSON.decoder.decode(ProfileDTO.self, from: Data(json.utf8))
    }
}

extension SubtaskDTO {
    static func make(id: UUID = UUID(), title: String, done: Bool = false) throws -> SubtaskDTO {
        let json = #"{"id":"\#(id)","title":"\#(title)","is_completed":\#(done),"order":0}"#
        return try OmakaseJSON.decoder.decode(SubtaskDTO.self, from: Data(json.utf8))
    }
}

extension WorkloadDTO {
    static func make(day: String, planned: Int = 0, goal: Int = 720, unestimated: Int = 0) throws -> WorkloadDTO {
        let json = """
            {"date":"\(day)","task_minutes":\(planned),"study_block_minutes":0,"class_minutes":0,
             "planned_minutes":\(planned),"goal_minutes":\(goal),"over_minutes":\(planned - goal),
             "unestimated_count":\(unestimated)}
            """
        return try OmakaseJSON.decoder.decode(WorkloadDTO.self, from: Data(json.utf8))
    }
}

/// The lists `FakeAPIClient` serves for the library (#224).
struct FakeLibrary: Sendable {
    var workspaces: [WorkspaceDTO] = []
    var projects: [ProjectDTO] = []
    var semesters: [SemesterDTO] = []
    var disciplines: [DisciplineDTO] = []
    var schedules: [ClassScheduleDTO] = []
    var holidays: [HolidayDTO] = []
    var inbox: [TaskDTO] = []
}
