import SwiftUI

struct HabitEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var habit: Habit
    @State private var reminderOn: Bool
    @State private var reminderTime: Date
    @State private var confirmDelete = false
    let isNew: Bool

    init(habit: Habit, isNew: Bool) {
        _habit = State(initialValue: habit)
        _reminderOn = State(initialValue: habit.reminder != nil)
        let minutes = habit.reminder ?? 9 * 60
        _reminderTime = State(initialValue: Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date())
        self.isNew = isNew
    }

    private var canSave: Bool {
        habit.isProgram || !habit.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if habit.isProgram {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(model.habitTitle(habit, day: model.today)).font(.ui(17, .medium))
                            Text("Part of your 60-day program. This task levels up every phase:")
                                .font(.ui(13)).foregroundStyle(Theme.text2)
                            ForEach(Array(habit.stages.enumerated()), id: \.offset) { i, stage in
                                Text("Phase \(roman(i + 1)) · \(stage.titles.count > 1 ? "\(stage.titles.count) rotating tasks" : stage.titles.first ?? "")")
                                    .font(.mono(11)).foregroundStyle(Theme.text3)
                            }
                        }
                    } else {
                        TextField("e.g. Read 20 pages", text: $habit.title)
                            .font(.ui(17, .medium))
                    }
                } header: {
                    Text("Task")
                }

                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                        ForEach(Stat.radarOrder) { stat in
                            Button {
                                habit.stat = stat
                                Feedback.tap()
                            } label: {
                                StatChip(stat: stat, selected: habit.stat == stat, compact: true)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Stat")
                } footer: {
                    Text(habit.stat.tagline)
                }

                if !habit.isProgram {
                    Section {
                        Picker("Difficulty", selection: $habit.difficulty) {
                            ForEach(Difficulty.allCases) { d in
                                Text("\(d.label) · \(d.xp) XP").tag(d)
                            }
                        }
                    } header: {
                        Text("Difficulty")
                    }
                }

                Section {
                    WeekdayPicker(weekdays: $habit.weekdays, color: habit.stat.color)
                    HStack {
                        presetButton("Every day", [1, 2, 3, 4, 5, 6, 7])
                        presetButton("Weekdays", [2, 3, 4, 5, 6])
                        presetButton("Weekends", [1, 7])
                    }
                } header: {
                    Text("Schedule")
                } footer: {
                    Text(habit.scheduleLabel)
                }

                Section {
                    Toggle("Remind me", isOn: $reminderOn)
                    if reminderOn {
                        DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Reminder")
                }

                if !isNew {
                    Section {
                        Button("Delete task", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle(isNew ? "New task" : "Edit task")
            .transparentNavBar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!canSave)
                }
            }
            .confirmationDialog("Delete this task?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    model.deleteHabit(habit)
                    dismiss()
                }
            } message: {
                Text("Past completions and XP are kept.")
            }
        }
        .sheetSize(width: 520, height: 700)
    }

    private func presetButton(_ title: String, _ days: [Int]) -> some View {
        Button(title) {
            habit.weekdays = days
            Feedback.tap()
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(Set(habit.weekdays) == Set(days) ? habit.stat.color : .gray)
    }

    private func save() {
        if reminderOn {
            let c = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
            habit.reminder = (c.hour ?? 9) * 60 + (c.minute ?? 0)
        } else {
            habit.reminder = nil
        }
        habit.title = habit.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if habit.weekdays.isEmpty { habit.weekdays = [1, 2, 3, 4, 5, 6, 7] }
        model.saveHabit(habit)
        Feedback.tap()
        dismiss()
    }
}

struct WeekdayPicker: View {
    @Binding var weekdays: [Int]
    var color: Color

    var body: some View {
        HStack(spacing: 6) {
            ForEach([2, 3, 4, 5, 6, 7, 1], id: \.self) { wd in
                let on = weekdays.contains(wd)
                Button {
                    if on { weekdays.removeAll { $0 == wd } } else { weekdays.append(wd) }
                    Feedback.tap()
                } label: {
                    Text(Day.shortWeekdays[wd - 1])
                        .font(.mono(13, .bold))
                        .foregroundStyle(on ? .black : Theme.text2)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(on ? color : Color.white.opacity(0.06)))
                        .shadow(color: on ? color.opacity(0.6) : .clear, radius: 6)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 4)
    }
}
