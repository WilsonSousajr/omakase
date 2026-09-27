import Foundation

// The library: what the Projects, Study and Settings screens edit (M5 spec
// §2). Online-only, so there are no outbox kinds for these (parent spec
// L136-139). Colours are the server's "#rrggbb" strings.

/// `WorkspaceSerializer`.
public struct WorkspaceDTO: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID
    public let name: String
    public let color: String
    public let projectCount: Int
}

/// `ProjectSerializer`: `status` is active, paused, completed or archived.
public struct ProjectDTO: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID
    public let workspace: UUID
    public let name: String
    public let description: String
    public let color: String
    public let status: String
    public let dueDate: APIDay?
    public let taskCount: Int
}

/// `SemesterSerializer`, with Week A/B rotation (#126): a null anchor means
/// the start date.
public struct SemesterDTO: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID
    public let name: String
    public let institution: String
    public let startDate: APIDay
    public let endDate: APIDay
    public let status: String
    public let rotationWeeks: Int
    public let rotationAnchor: APIDay?
}

/// `DisciplineSerializer`, the fields the Study screen shows.
public struct DisciplineDTO: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID
    public let semester: UUID
    public let name: String
    public let code: String
    public let professor: String
    public let color: String
    public let credits: Int?
    public let status: String
}

/// `ClassScheduleSerializer`: `dayOfWeek` 0 is Monday; an empty
/// `rotationWeeksOn` means every week (#126).
public struct ClassScheduleDTO: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID
    public let discipline: UUID
    public let dayOfWeek: Int
    public let startTime: String
    public let endTime: String
    public let classType: String
    public let location: String
    public let isActive: Bool
    public let rotationWeeksOn: [Int]
}

/// `HolidaySerializer`: both dates inclusive (#125).
public struct HolidayDTO: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID
    public let semester: UUID
    public let name: String
    public let startDate: APIDay
    public let endDate: APIDay
}
