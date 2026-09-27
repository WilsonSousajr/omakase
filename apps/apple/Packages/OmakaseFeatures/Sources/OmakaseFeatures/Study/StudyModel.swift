import Foundation
import Observation
import OmakaseStore

/// Study (#227): semesters, their disciplines and holidays, a discipline's
/// class schedules. Each is edited as a whole form, checked before it is
/// sent, and written online (parent spec L136-139). A refusal keeps the form
/// open and says why; a delete asks first and says what cascades.
///
///     study.editing = .semester(form, id: nil)
///     await study.saveEditing()
@Observable
@MainActor
public final class StudyModel {
    public struct Actions {
        let saveSemester: (SemesterForm, String?) async throws -> Void
        let saveDiscipline: (DisciplineForm, String?) async throws -> Void
        let saveSchedule: (ClassScheduleForm, String?) async throws -> Void
        let saveHoliday: (HolidayForm, String?) async throws -> Void
        let delete: (Deletion) async throws -> Void

        public init(
            saveSemester: @escaping (SemesterForm, String?) async throws -> Void,
            saveDiscipline: @escaping (DisciplineForm, String?) async throws -> Void,
            saveSchedule: @escaping (ClassScheduleForm, String?) async throws -> Void,
            saveHoliday: @escaping (HolidayForm, String?) async throws -> Void,
            delete: @escaping (Deletion) async throws -> Void
        ) {
            (self.saveSemester, self.saveDiscipline) = (saveSemester, saveDiscipline)
            (self.saveSchedule, self.saveHoliday, self.delete) = (saveSchedule, saveHoliday, delete)
        }
    }

    /// What a delete takes with it, as the server cascades.
    public enum Deletion: Equatable, Sendable {
        case semester(id: String)
        case discipline(id: String)
        case schedule(id: String)
        case holiday(id: String)

        public var id: String {
            switch self {
            case .semester(let id), .discipline(let id), .schedule(let id), .holiday(let id): id
            }
        }

        public var warning: String {
            switch self {
            case .semester: "Its disciplines, their classes and its holidays go too."
            case .discipline: "Its classes go too. Its tasks and study blocks stay."
            case .schedule: "Its classes leave the calendar."
            case .holiday: "Its days have classes again."
            }
        }
    }

    public var selectedSemesterID: String?
    public var selectedDisciplineID: String?
    public var editing: StudyForm?
    public private(set) var message: String?
    public private(set) var deleting: Deletion?

    @ObservationIgnored private let actions: Actions

    public init(actions: Actions) { self.actions = actions }

    public func saveEditing() async {
        guard let form = editing else { return }
        if let problem = StudyCheck.problem(form) {
            message = problem
            return
        }
        do {
            try await send(form)
            (editing, message) = (nil, nil)
        } catch {
            message = String(describing: error)
        }
    }

    public func cancelEditing() { (editing, message) = (nil, nil) }

    public func askToDelete(_ deletion: Deletion) { deleting = deletion }

    public func cancelDelete() { deleting = nil }

    public func confirmDelete() async {
        guard let deletion = deleting else { return }
        deleting = nil
        do {
            try await actions.delete(deletion)
            message = nil
        } catch {
            message = String(describing: error)
        }
    }

    /// The semester today falls in; else the next to start; else the latest.
    public static func defaultSemester(_ semesters: [SemesterSummary], today: String) -> String? {
        if let current = semesters.first(where: { $0.startDay <= today && today <= $0.endDay }) { return current.id }
        let upcoming = semesters.filter { $0.startDay > today }.min { $0.startDay < $1.startDay }
        return (upcoming ?? semesters.max { $0.startDay < $1.startDay })?.id
    }

    private func send(_ form: StudyForm) async throws {
        switch form {
        case .semester(let semester, let id): try await actions.saveSemester(semester, id)
        case .discipline(let discipline, let id): try await actions.saveDiscipline(discipline, id)
        case .schedule(let schedule, let id, _): try await actions.saveSchedule(schedule, id)
        case .holiday(let holiday, let id): try await actions.saveHoliday(holiday, id)
        }
    }
}
