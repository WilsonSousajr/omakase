import Foundation

// Study's forms (#227): what a create or an edit sends, whole. Parent ids
// go lowercased, as Django's uuid path converter expects elsewhere; times
// are the server's "HH:MM:SS" wall clock.

public struct SemesterForm: Equatable, Sendable, Encodable {
    public var name: String
    public var institution: String
    public var startDay: String
    public var endDay: String
    /// Week A/B (#126): 1 is every week the same.
    public var rotationWeeks: Int
    /// nil anchors the rotation on the start date, sent as an explicit null.
    public var rotationAnchor: String?

    public init(
        name: String, institution: String, startDay: String, endDay: String, rotationWeeks: Int = 1,
        rotationAnchor: String? = nil
    ) {
        (self.name, self.institution, self.startDay, self.endDay) = (name, institution, startDay, endDay)
        (self.rotationWeeks, self.rotationAnchor) = (rotationWeeks, rotationAnchor)
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case institution
        case startDay = "start_date"
        case endDay = "end_date"
        case rotationWeeks = "rotation_weeks"
        case rotationAnchor = "rotation_anchor"
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(institution, forKey: .institution)
        try container.encode(startDay, forKey: .startDay)
        try container.encode(endDay, forKey: .endDay)
        try container.encode(rotationWeeks, forKey: .rotationWeeks)
        try container.encode(rotationAnchor, forKey: .rotationAnchor)
    }
}

public struct DisciplineForm: Equatable, Sendable, Encodable {
    public var semesterID: String
    public var name: String
    public var code: String
    public var professor: String
    public var color: String

    public init(semesterID: String, name: String, code: String, professor: String, color: String) {
        (self.semesterID, self.name, self.code, self.professor, self.color) = (
            semesterID, name, code, professor, color
        )
    }

    private enum CodingKeys: String, CodingKey {
        case semesterID = "semester"
        case name
        case code
        case professor
        case color
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(semesterID.lowercased(), forKey: .semesterID)
        try container.encode(name, forKey: .name)
        try container.encode(code, forKey: .code)
        try container.encode(professor, forKey: .professor)
        try container.encode(color, forKey: .color)
    }
}

public struct ClassScheduleForm: Equatable, Sendable, Encodable {
    public var disciplineID: String
    /// 0 is Monday.
    public var dayOfWeek: Int
    public var startTime: String
    public var endTime: String
    /// lecture, lab, tutorial or seminar.
    public var classType: String
    public var location: String
    /// The rotation's weeks it runs in (#126); empty is every week.
    public var rotationWeeksOn: [Int]

    public init(
        disciplineID: String, dayOfWeek: Int, startTime: String, endTime: String, classType: String,
        location: String, rotationWeeksOn: [Int] = []
    ) {
        (self.disciplineID, self.dayOfWeek, self.startTime, self.endTime) = (
            disciplineID, dayOfWeek, startTime, endTime
        )
        (self.classType, self.location, self.rotationWeeksOn) = (classType, location, rotationWeeksOn)
    }

    private enum CodingKeys: String, CodingKey {
        case disciplineID = "discipline"
        case dayOfWeek = "day_of_week"
        case startTime = "start_time"
        case endTime = "end_time"
        case classType = "class_type"
        case location
        case rotationWeeksOn = "rotation_weeks_on"
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(disciplineID.lowercased(), forKey: .disciplineID)
        try container.encode(dayOfWeek, forKey: .dayOfWeek)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(endTime, forKey: .endTime)
        try container.encode(classType, forKey: .classType)
        try container.encode(location, forKey: .location)
        try container.encode(rotationWeeksOn, forKey: .rotationWeeksOn)
    }
}

public struct HolidayForm: Equatable, Sendable, Encodable {
    public var semesterID: String
    public var name: String
    /// Both inclusive (#125).
    public var startDay: String
    public var endDay: String

    public init(semesterID: String, name: String, startDay: String, endDay: String) {
        (self.semesterID, self.name, self.startDay, self.endDay) = (semesterID, name, startDay, endDay)
    }

    private enum CodingKeys: String, CodingKey {
        case semesterID = "semester"
        case name
        case startDay = "start_date"
        case endDay = "end_date"
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(semesterID.lowercased(), forKey: .semesterID)
        try container.encode(name, forKey: .name)
        try container.encode(startDay, forKey: .startDay)
        try container.encode(endDay, forKey: .endDay)
    }
}
