import Foundation
import OmakaseAPI
import SwiftData

// The library as the Mac caches it (#224): the server's copy, refreshed by
// LibrarySync and written only online (M5 spec, Decisions). Ids are the
// server's UUIDs as strings; colours are "#rrggbb".

/// A server record the library caches: made from its DTO, then kept in step.
public protocol LibraryCached: PersistentModel {
    associatedtype DTO: Identifiable & Sendable & Decodable where DTO.ID == UUID
    var id: String { get }
    init(dto: DTO)
    func apply(_ dto: DTO)
}

@Model
public final class WorkspaceRecord: LibraryCached {
    @Attribute(.unique) public var id: String
    public var name = ""
    public var color = ""
    public var projectCount = 0

    public init(dto: WorkspaceDTO) {
        id = dto.id.uuidString
        apply(dto)
    }

    public func apply(_ dto: WorkspaceDTO) { (name, color, projectCount) = (dto.name, dto.color, dto.projectCount) }
}

@Model
public final class ProjectRecord: LibraryCached {
    @Attribute(.unique) public var id: String
    public var workspaceID = ""
    public var name = ""
    public var details = ""
    public var color = ""
    /// active, paused, completed or archived.
    public var status = ""
    public var dueDay: String?
    public var taskCount = 0

    public init(dto: ProjectDTO) {
        id = dto.id.uuidString
        apply(dto)
    }

    public func apply(_ dto: ProjectDTO) {
        (workspaceID, name, details, color) = (dto.workspace.uuidString, dto.name, dto.description, dto.color)
        (status, dueDay, taskCount) = (dto.status, dto.dueDate?.string, dto.taskCount)
    }
}

@Model
public final class SemesterRecord: LibraryCached {
    @Attribute(.unique) public var id: String
    public var name = ""
    public var institution = ""
    public var startDay = ""
    public var endDay = ""
    public var status = ""
    /// Week A/B rotation (#126): 1 is every week the same; nil anchor is the start.
    public var rotationWeeks = 1
    public var rotationAnchor: String?

    public init(dto: SemesterDTO) {
        id = dto.id.uuidString
        apply(dto)
    }

    public func apply(_ dto: SemesterDTO) {
        (name, institution, status) = (dto.name, dto.institution, dto.status)
        (startDay, endDay) = (dto.startDate.string, dto.endDate.string)
        (rotationWeeks, rotationAnchor) = (dto.rotationWeeks, dto.rotationAnchor?.string)
    }
}

@Model
public final class DisciplineRecord: LibraryCached {
    @Attribute(.unique) public var id: String
    public var semesterID = ""
    public var name = ""
    public var code = ""
    public var professor = ""
    public var color = ""
    public var credits: Int?
    public var status = ""

    public init(dto: DisciplineDTO) {
        id = dto.id.uuidString
        apply(dto)
    }

    public func apply(_ dto: DisciplineDTO) {
        (semesterID, name, code, professor) = (dto.semester.uuidString, dto.name, dto.code, dto.professor)
        (color, credits, status) = (dto.color, dto.credits, dto.status)
    }
}

@Model
public final class ClassScheduleRecord: LibraryCached {
    @Attribute(.unique) public var id: String
    public var disciplineID = ""
    /// 0 is Monday.
    public var dayOfWeek = 0
    public var startTime = ""
    public var endTime = ""
    public var classType = ""
    public var location = ""
    public var isActive = true
    /// Empty means every week of the rotation (#126).
    public var rotationWeeksOn: [Int] = []

    public init(dto: ClassScheduleDTO) {
        id = dto.id.uuidString
        apply(dto)
    }

    public func apply(_ dto: ClassScheduleDTO) {
        (disciplineID, dayOfWeek, startTime, endTime) = (
            dto.discipline.uuidString, dto.dayOfWeek, dto.startTime, dto.endTime
        )
        (classType, location, isActive, rotationWeeksOn) = (
            dto.classType, dto.location, dto.isActive, dto.rotationWeeksOn
        )
    }
}

@Model
public final class HolidayRecord: LibraryCached {
    @Attribute(.unique) public var id: String
    public var semesterID = ""
    public var name = ""
    /// Both inclusive (#125).
    public var startDay = ""
    public var endDay = ""

    public init(dto: HolidayDTO) {
        id = dto.id.uuidString
        apply(dto)
    }

    public func apply(_ dto: HolidayDTO) {
        (semesterID, name, startDay, endDay) = (
            dto.semester.uuidString, dto.name, dto.startDate.string, dto.endDate.string
        )
    }
}
