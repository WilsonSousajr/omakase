import OmakaseStore
import SwiftData
import SwiftUI

/// Settings (⌘,; #228): the account, the week, the timer, the goals, the
/// reminders and Calendar.app. Each change is saved online after a pause;
/// a refusal shows at the foot and the value goes back.
public struct SettingsView: View {
    @Bindable private var model: SettingsModel
    private let overlay: CalendarOverlayModel?
    private let signOut: () -> Void
    @Query private var profiles: [ProfileRecord]

    public init(model: SettingsModel, overlay: CalendarOverlayModel?, signOut: @escaping () -> Void) {
        (self.model, self.overlay, self.signOut) = (model, overlay, signOut)
    }

    public var body: some View {
        VStack(spacing: 0) {
            TabView {
                SettingsAccountTab(model: model, signOut: signOut).tabItem { Label("Account", systemImage: "person") }
                SettingsGeneralTab(model: model).tabItem { Label("General", systemImage: "gearshape") }
                SettingsFocusTab(model: model).tabItem { Label("Focus", systemImage: "timer") }
                SettingsRemindersTab(model: model).tabItem { Label("Reminders", systemImage: "bell") }
                SettingsIntegrationsTab(overlay: overlay).tabItem { Label("Calendar", systemImage: "calendar") }
            }
            if let message = model.message {
                Text(message).font(TypeScale.caption).foregroundStyle(Palette.inkMuted.color).padding(Spacing.medium)
            }
        }
        .frame(width: 480)
        .tint(AppTint.window.color)
        .onChange(of: profiles.first.map(ProfileValues.init(record:)), initial: true) { _, values in
            if let values { model.load(values) }
        }
        .task { await model.loadAccount() }
    }
}

/// A binding into the draft that saves after a pause.
@MainActor
func draftBinding<Value>(
    _ model: SettingsModel, _ field: WritableKeyPath<ProfileValues, Value>, _ fallback: Value
) -> Binding<Value> {
    Binding(
        get: { model.draft?[keyPath: field] ?? fallback },
        set: { value in
            model.draft?[keyPath: field] = value
            model.changed()
        })
}

struct SettingsAccountTab: View {
    let model: SettingsModel
    let signOut: () -> Void

    var body: some View {
        Form {
            LabeledContent("Signed in as", value: model.email ?? "…")
            Button("Sign Out…", role: .destructive) { signOut() }
        }
        .formStyle(.grouped)
    }
}

struct SettingsGeneralTab: View {
    let model: SettingsModel

    var body: some View {
        Form {
            Picker("Week starts on", selection: draftBinding(model, \.weekStartsOn, "monday")) {
                Text("Monday").tag("monday")
                Text("Sunday").tag("sunday")
            }
            LabeledContent("Time zone", value: model.draft?.timezone ?? "…")
            Toggle(
                "Open at login",
                isOn: Binding(get: { model.launchesAtLogin }, set: { model.setLaunchesAtLogin($0) }))
        }
        .formStyle(.grouped)
    }
}

struct SettingsFocusTab: View {
    let model: SettingsModel

    var body: some View {
        Form {
            Section("Pomodoro") {
                Stepper(value: draftBinding(model, \.workMinutes, 25), in: 5...120, step: 5) {
                    LabeledContent("Focus", value: "\(model.draft?.workMinutes ?? 25) min")
                }
                Stepper(value: draftBinding(model, \.shortBreakMinutes, 5), in: 1...30) {
                    LabeledContent("Short break", value: "\(model.draft?.shortBreakMinutes ?? 5) min")
                }
                Stepper(value: draftBinding(model, \.longBreakMinutes, 15), in: 5...60, step: 5) {
                    LabeledContent("Long break", value: "\(model.draft?.longBreakMinutes ?? 15) min")
                }
                Stepper(value: draftBinding(model, \.beforeLongBreak, 4), in: 2...8) {
                    LabeledContent("Sessions before a long break", value: "\(model.draft?.beforeLongBreak ?? 4)")
                }
            }
            SettingsGoalsSection(model: model)
        }
        .formStyle(.grouped)
    }
}

struct SettingsGoalsSection: View {
    let model: SettingsModel

    var body: some View {
        Section("Daily goals") {
            Stepper(value: draftBinding(model, \.workGoalHours, 8), in: 0...16, step: 0.5) {
                LabeledContent("Work", value: hours(model.draft?.workGoalHours ?? 8))
            }
            Stepper(value: draftBinding(model, \.studyGoalHours, 4), in: 0...16, step: 0.5) {
                LabeledContent("Study", value: hours(model.draft?.studyGoalHours ?? 4))
            }
        }
    }

    private func hours(_ value: Double) -> String { MinutesText.format(Int(value * 60)) }
}

struct SettingsRemindersTab: View {
    let model: SettingsModel

    var body: some View {
        Form {
            Section("Before each block") {
                Toggle("Heads-up", isOn: headsUpOn)
                if let minutes = model.draft?.blockReminderMinutes {
                    Stepper(value: headsUpMinutes, in: 1...120) {
                        LabeledContent("Minutes before", value: "\(minutes)")
                    }
                }
            }
            Section("End of the day") {
                Toggle("Shutdown reminder", isOn: shutdownOn)
                if model.draft?.shutdownReminderTime != nil {
                    DatePicker("At", selection: shutdownTime, displayedComponents: .hourAndMinute)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var headsUpOn: Binding<Bool> {
        Binding(
            get: { model.draft?.blockReminderMinutes != nil },
            set: { isOn in
                model.draft?.blockReminderMinutes = isOn ? 5 : nil
                model.changed()
            })
    }

    private var headsUpMinutes: Binding<Int> {
        Binding(
            get: { model.draft?.blockReminderMinutes ?? 5 },
            set: { minutes in
                model.draft?.blockReminderMinutes = minutes
                model.changed()
            })
    }

    private var shutdownOn: Binding<Bool> {
        Binding(
            get: { model.draft?.shutdownReminderTime != nil },
            set: { isOn in
                model.draft?.shutdownReminderTime = isOn ? "18:00:00" : nil
                model.changed()
            })
    }

    private var shutdownTime: Binding<Date> {
        let calendar = Calendar.current
        let today = DayString.format(.now, calendar: calendar)
        return Binding(
            get: {
                let time = model.draft?.shutdownReminderTime ?? "18:00:00"
                return ReminderClock.date(day: today, time: time, calendar: calendar) ?? .now
            },
            set: { date in
                model.draft?.shutdownReminderTime = ReminderClock.time(from: date, calendar: calendar)
                model.changed()
            })
    }
}

struct SettingsIntegrationsTab: View {
    let overlay: CalendarOverlayModel?

    var body: some View {
        Form {
            if let overlay {
                Toggle(
                    "Show Calendar.app's events on Plan",
                    isOn: Binding(get: { overlay.isEnabled }, set: { isOn in Task { await overlay.setEnabled(isOn) } }))
                if let message = overlay.message {
                    Text(message).font(TypeScale.caption).foregroundStyle(Palette.inkMuted.color)
                }
                Text("Read-only: Omakase never changes your calendar.").font(TypeScale.caption).foregroundStyle(
                    Palette.inkMuted.color)
            }
        }
        .formStyle(.grouped)
    }
}
