import OmakaseStore
import SwiftUI

/// The open Study form (#227), edited as a local copy and handed back to the
/// model on Save, which checks it, sends it, and closes it on success.
struct StudyFormSheet: View {
    let model: StudyModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            switch model.editing {
            case .semester(let form, let id): SemesterFormView(form: form) { model.editing = .semester($0, id: id) }
            case .discipline(let form, let id):
                DisciplineFormView(form: form) { model.editing = .discipline($0, id: id) }
            case .schedule(let form, let id, let weeks):
                ClassScheduleFormView(form: form, rotationWeeks: weeks) {
                    model.editing = .schedule($0, id: id, rotationWeeks: weeks)
                }
            case .holiday(let form, let id): HolidayFormView(form: form) { model.editing = .holiday($0, id: id) }
            case nil: EmptyView()
            }
            if let message = model.message {
                Text(message).font(TypeScale.caption).foregroundStyle(Palette.inkMuted.color)
            }
            HStack {
                Spacer()
                Button("Cancel") { model.cancelEditing() }.buttonStyle(.glass).keyboardShortcut(.cancelAction)
                Button("Save") { Task { await model.saveEditing() } }.buttonStyle(.primary)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Spacing.large)
        .frame(width: 420)
    }
}

/// A day string edited with a date picker.
@MainActor
func dayBinding(_ day: Binding<String>) -> Binding<Date> {
    let calendar = Calendar.current
    return Binding(
        get: { DayString.date(day.wrappedValue, calendar: calendar) ?? .now },
        set: { day.wrappedValue = DayString.format($0, calendar: calendar) })
}

/// A "HH:MM:SS" time edited with a time picker.
@MainActor
func timeBinding(_ time: Binding<String>) -> Binding<Date> {
    let calendar = Calendar.current
    let today = DayString.format(.now, calendar: calendar)
    return Binding(
        get: { ReminderClock.date(day: today, time: time.wrappedValue, calendar: calendar) ?? .now },
        set: { time.wrappedValue = ReminderClock.time(from: $0, calendar: calendar) })
}

struct SemesterFormView: View {
    @State var form: SemesterForm
    let update: (SemesterForm) -> Void

    var body: some View {
        Form {
            TextField("Name", text: $form.name)
            TextField("Institution", text: $form.institution)
            DatePicker("Starts", selection: dayBinding($form.startDay), displayedComponents: .date)
            DatePicker("Ends", selection: dayBinding($form.endDay), displayedComponents: .date)
            Stepper(value: $form.rotationWeeks, in: 1...4) {
                LabeledContent(
                    "Rotation", value: form.rotationWeeks == 1 ? "Every week the same" : "\(form.rotationWeeks) weeks")
            }
        }
        .onChange(of: form) { _, value in update(value) }
    }
}

struct DisciplineFormView: View {
    @State var form: DisciplineForm
    let update: (DisciplineForm) -> Void

    var body: some View {
        Form {
            TextField("Name", text: $form.name)
            TextField("Code", text: $form.code)
            TextField("Professor", text: $form.professor)
            Picker("Colour", selection: $form.color) {
                ForEach(ProjectsModel.palette, id: \.self) { hex in
                    Label(hex, systemImage: "circle.fill").tint(DesignColor(hex: hex)?.color).tag(hex)
                }
            }
        }
        .onChange(of: form) { _, value in update(value) }
    }
}

struct ClassScheduleFormView: View {
    @State var form: ClassScheduleForm
    let rotationWeeks: Int
    let update: (ClassScheduleForm) -> Void

    var body: some View {
        Form {
            Picker("Day", selection: $form.dayOfWeek) {
                ForEach(StudyForms.weekdays.indices, id: \.self) { day in Text(StudyForms.weekdays[day]).tag(day) }
            }
            DatePicker("Starts", selection: timeBinding($form.startTime), displayedComponents: .hourAndMinute)
            DatePicker("Ends", selection: timeBinding($form.endTime), displayedComponents: .hourAndMinute)
            Picker("Type", selection: $form.classType) {
                ForEach(StudyForms.classTypes, id: \.self) { type in Text(type.capitalized).tag(type) }
            }
            TextField("Location", text: $form.location)
            if rotationWeeks > 1 { weeks }
        }
        .onChange(of: form) { _, value in update(value) }
    }

    private var weeks: some View {
        Section("Runs in") {
            ForEach(1...rotationWeeks, id: \.self) { week in
                Toggle("Week \(week)", isOn: runs(in: week))
            }
            Text("None chosen means every week.").font(TypeScale.caption).foregroundStyle(Palette.inkMuted.color)
        }
    }

    private func runs(in week: Int) -> Binding<Bool> {
        Binding(
            get: { form.rotationWeeksOn.contains(week) },
            set: { isOn in
                form.rotationWeeksOn =
                    isOn ? (form.rotationWeeksOn + [week]).sorted() : form.rotationWeeksOn.filter { $0 != week }
            })
    }
}

struct HolidayFormView: View {
    @State var form: HolidayForm
    let update: (HolidayForm) -> Void

    var body: some View {
        Form {
            TextField("Name", text: $form.name)
            DatePicker("From", selection: dayBinding($form.startDay), displayedComponents: .date)
            DatePicker("To", selection: dayBinding($form.endDay), displayedComponents: .date)
        }
        .onChange(of: form) { _, value in update(value) }
    }
}
