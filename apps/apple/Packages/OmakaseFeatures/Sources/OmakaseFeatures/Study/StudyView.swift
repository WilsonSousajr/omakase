import OmakaseStore
import SwiftData
import SwiftUI

/// Study (#227): semesters, then the chosen semester's disciplines and
/// holidays, then the chosen discipline's classes. Every write is online; a
/// failure is said at the foot, and a form stays open with its reason.
public struct StudyView: View {
    private let day: String
    @Bindable private var model: StudyModel
    @Query(sort: \SemesterRecord.startDay, order: .reverse) private var semesters: [SemesterRecord]
    @Query(sort: \DisciplineRecord.name) private var disciplines: [DisciplineRecord]
    @Query(sort: \ClassScheduleRecord.dayOfWeek) private var schedules: [ClassScheduleRecord]
    @Query(sort: \HolidayRecord.startDay) private var holidays: [HolidayRecord]

    public init(day: String, model: StudyModel) { (self.day, self.model) = (day, model) }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                StudySemesterColumn(model: model, semesters: semesters, day: day).frame(width: 220)
                Divider().overlay(Palette.hairline.color)
                StudySemesterDetail(
                    model: model, semester: semester, disciplines: semesterDisciplines, holidays: semesterHolidays
                )
                .frame(width: 280)
                Divider().overlay(Palette.hairline.color)
                StudyClassesColumn(
                    model: model, discipline: discipline, schedules: disciplineSchedules, rotation: rotation)
            }
            if let message = model.message, model.editing == nil {
                Text(message).font(TypeScale.caption).foregroundStyle(Palette.inkMuted.color).padding(Spacing.medium)
            }
        }
        .sheet(isPresented: editing) { StudyFormSheet(model: model) }
        .confirmationDialog(
            "Delete this?", isPresented: deleting, titleVisibility: .visible,
            actions: {
                Button("Delete", role: .destructive) { Task { await model.confirmDelete() } }
                Button("Cancel", role: .cancel) { model.cancelDelete() }
            },
            message: { Text(model.deleting?.warning ?? "") }
        )
        .onAppear(perform: chooseSemester)
    }

    private var semester: SemesterRecord? { semesters.first { $0.id == model.selectedSemesterID } }
    private var semesterDisciplines: [DisciplineRecord] {
        disciplines.filter { $0.semesterID == model.selectedSemesterID }
    }
    private var semesterHolidays: [HolidayRecord] { holidays.filter { $0.semesterID == model.selectedSemesterID } }
    private var discipline: DisciplineRecord? { semesterDisciplines.first { $0.id == model.selectedDisciplineID } }
    private var disciplineSchedules: [ClassScheduleRecord] { schedules.filter { $0.disciplineID == discipline?.id } }
    private var rotation: Int { semester?.rotationWeeks ?? 1 }

    private var editing: Binding<Bool> {
        Binding(get: { model.editing != nil }, set: { if !$0 { model.cancelEditing() } })
    }

    private var deleting: Binding<Bool> {
        Binding(get: { model.deleting != nil }, set: { if !$0 { model.cancelDelete() } })
    }

    private func chooseSemester() {
        guard model.selectedSemesterID == nil else { return }
        let summaries = semesters.map { SemesterSummary(id: $0.id, startDay: $0.startDay, endDay: $0.endDay) }
        model.selectedSemesterID = StudyModel.defaultSemester(summaries, today: day)
    }
}

struct StudySemesterColumn: View {
    @Bindable var model: StudyModel
    let semesters: [SemesterRecord]
    let day: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Semesters").sectionLabel().padding(Spacing.medium)
            List(selection: $model.selectedSemesterID) {
                ForEach(semesters) { semester in
                    VStack(alignment: .leading, spacing: Spacing.tiny) {
                        Text(semester.name).foregroundStyle(Palette.ink.color)
                        Text("\(semester.startDay) – \(semester.endDay)").font(TypeScale.caption)
                            .foregroundStyle(Palette.inkMuted.color)
                    }
                    .tag(Optional(semester.id))
                    .contextMenu {
                        Button("Edit…") { model.editing = .semester(StudyForms.form(semester), id: semester.id) }
                        Button("Delete…", role: .destructive) { model.askToDelete(.semester(id: semester.id)) }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            Button("New Semester…") { model.editing = .semester(StudyForms.newSemester(today: day), id: nil) }
                .buttonStyle(.glass).padding(Spacing.medium)
        }
    }
}

struct StudySemesterDetail: View {
    @Bindable var model: StudyModel
    let semester: SemesterRecord?
    let disciplines: [DisciplineRecord]
    let holidays: [HolidayRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let semester {
                Text("Disciplines").sectionLabel().padding(Spacing.medium)
                List(selection: $model.selectedDisciplineID) {
                    ForEach(disciplines) { discipline in disciplineRow(discipline) }
                    Section("Holidays") { ForEach(holidays) { holiday in holidayRow(holiday) } }
                }
                .scrollContentBackground(.hidden)
                HStack {
                    Button("New Discipline…") {
                        model.editing = .discipline(StudyForms.newDiscipline(in: semester.id), id: nil)
                    }
                    Button("New Holiday…") { model.editing = .holiday(StudyForms.newHoliday(in: semester), id: nil) }
                }
                .buttonStyle(.glass).padding(Spacing.medium)
            } else {
                StudyEmptyView(text: "Choose or create a semester.")
            }
        }
    }

    private func disciplineRow(_ discipline: DisciplineRecord) -> some View {
        HStack(spacing: Spacing.small) {
            Circle().fill(DesignColor(hex: discipline.color)?.color ?? Palette.accent.color).frame(width: 8, height: 8)
            Text(discipline.name).foregroundStyle(Palette.ink.color)
            if !discipline.code.isEmpty {
                Text(discipline.code).font(TypeScale.caption).foregroundStyle(Palette.inkMuted.color)
            }
        }
        .tag(Optional(discipline.id))
        .contextMenu {
            Button("Edit…") { model.editing = .discipline(StudyForms.form(discipline), id: discipline.id) }
            Button("Delete…", role: .destructive) { model.askToDelete(.discipline(id: discipline.id)) }
        }
    }

    private func holidayRow(_ holiday: HolidayRecord) -> some View {
        VStack(alignment: .leading, spacing: Spacing.tiny) {
            Text(holiday.name).foregroundStyle(Palette.ink.color)
            Text("\(holiday.startDay) – \(holiday.endDay)").font(TypeScale.caption).foregroundStyle(
                Palette.inkMuted.color)
        }
        .contextMenu {
            Button("Edit…") { model.editing = .holiday(StudyForms.form(holiday), id: holiday.id) }
            Button("Delete…", role: .destructive) { model.askToDelete(.holiday(id: holiday.id)) }
        }
    }
}

struct StudyClassesColumn: View {
    let model: StudyModel
    let discipline: DisciplineRecord?
    let schedules: [ClassScheduleRecord]
    let rotation: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let discipline {
                Text(discipline.professor.isEmpty ? discipline.name : "\(discipline.name) · \(discipline.professor)")
                    .sectionLabel().padding(Spacing.medium)
                ScrollView {
                    VStack(spacing: Spacing.small) { ForEach(schedules) { schedule in row(schedule) } }
                        .padding(.horizontal, Spacing.medium)
                }
                Button("New Class…") {
                    model.editing = .schedule(
                        StudyForms.newSchedule(for: discipline.id), id: nil, rotationWeeks: rotation)
                }
                .buttonStyle(.glass).padding(Spacing.medium)
            } else {
                StudyEmptyView(text: "Choose a discipline to see its classes.")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ schedule: ClassScheduleRecord) -> some View {
        HStack {
            Text(StudyForms.weekdayName(schedule.dayOfWeek)).frame(width: 90, alignment: .leading)
            Text("\(schedule.startTime.prefix(5))–\(schedule.endTime.prefix(5))").monospacedDigit()
            Text(schedule.classType.capitalized).foregroundStyle(Palette.inkMuted.color)
            Spacer()
            Text(StudyForms.weeksLabel(schedule.rotationWeeksOn)).font(TypeScale.caption).foregroundStyle(
                Palette.inkMuted.color)
        }
        .font(TypeScale.body).foregroundStyle(Palette.ink.color)
        .padding(Spacing.small)
        .background(Palette.surface.color, in: .rect(cornerRadius: Radius.small))
        .contextMenu {
            Button("Edit…") {
                model.editing = .schedule(StudyForms.form(schedule), id: schedule.id, rotationWeeks: rotation)
            }
            Button("Delete…", role: .destructive) { model.askToDelete(.schedule(id: schedule.id)) }
        }
    }
}

struct StudyEmptyView: View {
    let text: String

    var body: some View {
        Text(text).font(TypeScale.body).foregroundStyle(Palette.inkMuted.color)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
