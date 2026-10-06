import SwiftUI

struct WorkoutsView: View {
    @Environment(AppModel.self) private var model
    @State private var active: WorkoutLog? = nil
    @State private var editingTemplate: WorkoutTemplate? = nil

    private let color = Stat.physical.color

    var body: some View {
        let bests = model.personalBests()
        let unit = model.settings.weightUnit.rawValue
        ScreenScroll(spacing: 20) {
            ToolHeader(title: "Lift.", subtitle: "Log sets, beat your numbers. Every workout earns Physical XP, every PR earns a bonus.", color: color)

            Button {
                active = WorkoutLog(name: "Workout", day: model.today, date: Date(), exercises: [])
            } label: {
                Label("Start empty workout", systemImage: "plus")
            }
            .buttonStyle(NeonButtonStyle(color: color, filled: true))

            SectionHeader(title: "Templates") {
                Button {
                    editingTemplate = WorkoutTemplate(name: "", exercises: [])
                } label: {
                    Label("New", systemImage: "plus").font(.ui(14, .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(color)
            }
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(model.templates) { t in
                        Button {
                            active = start(from: t)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(t.name).font(.ui(18, .semibold)).foregroundStyle(.white)
                                Text(t.exercises.prefix(3).joined(separator: "\n"))
                                    .font(.ui(12))
                                    .foregroundStyle(Theme.text2)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                                MonoLabel("\(t.exercises.count) exercises", color: color, size: 10)
                            }
                            .frame(width: 150, height: 140, alignment: .topLeading)
                            .padding(14)
                            .neonCard(color, radius: 18, glow: false)
                        }
                        .buttonStyle(PressableStyle())
                        .contextMenu {
                            Button("Edit template", systemImage: "pencil") { editingTemplate = t }
                            Button("Delete template", systemImage: "trash", role: .destructive) { model.deleteTemplate(t) }
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 2)
            }
            .scrollIndicators(.never)

            if !bests.isEmpty {
                SectionHeader("Personal records")
                VStack(spacing: 8) {
                    ForEach(Array(bests.keys.sorted { (bests[$0] ?? 0) > (bests[$1] ?? 0) }.prefix(8)), id: \.self) { name in
                        HStack {
                            Image(systemName: "trophy.fill").foregroundStyle(Stat.mental.color)
                            Text(name).font(.ui(15)).foregroundStyle(.white)
                            Spacer()
                            MonoLabel("e1RM \((bests[name] ?? 0).clean) \(unit)", color: .white, size: 11)
                        }
                        .padding(12)
                        .glassCard(radius: 14)
                    }
                }
            }

            SectionHeader("History")
            if model.workouts.isEmpty {
                Text("No workouts yet. Start one above.")
                    .font(.ui(14))
                    .foregroundStyle(Theme.text3)
            }
            ForEach(model.workouts) { w in
                Button {
                    active = w
                } label: {
                    HStack(spacing: 14) {
                        HexIcon(color: color, size: 34, symbol: "dumbbell.fill")
                        VStack(alignment: .leading, spacing: 3) {
                            Text(w.name).font(.ui(16, .semibold)).foregroundStyle(.white)
                            MonoLabel("\(Day.short(w.day)) · \(w.completedSets) sets · \(Int(w.volume).grouped) \(unit)", size: 10)
                        }
                        Spacer()
                        if w.durationSeconds > 0 {
                            MonoLabel("\(w.durationSeconds / 60) min", color: color, size: 11)
                        }
                    }
                    .padding(14)
                    .glassCard(radius: 16)
                }
                .buttonStyle(PressableStyle())
                .contextMenu {
                    Button("Delete workout", systemImage: "trash", role: .destructive) { model.deleteWorkout(w) }
                }
            }
        }
        .transparentNavBar()
        .coverSheet(isPresented: Binding(get: { active != nil }, set: { if !$0 { active = nil } })) {
            if let w = active {
                ActiveWorkoutView(workout: w)
            }
        }
        .sheet(item: $editingTemplate) { t in
            TemplateEditor(template: t)
        }
    }

    private func start(from template: WorkoutTemplate) -> WorkoutLog {
        let exercises = template.exercises.map { name in
            ExerciseLog(name: name, sets: model.lastSets(for: name) ?? [SetLog(reps: 8, weight: 0), SetLog(reps: 8, weight: 0), SetLog(reps: 8, weight: 0)])
        }
        return WorkoutLog(name: template.name, day: model.today, date: Date(), exercises: exercises)
    }
}

// MARK: - Active workout

struct ActiveWorkoutView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var workout: WorkoutLog
    @State private var picking = false
    @State private var confirmDiscard = false
    @State private var started: Date
    private let isExisting: Bool

    init(workout: WorkoutLog) {
        _workout = State(initialValue: workout)
        _started = State(initialValue: Date())
        isExisting = workout.durationSeconds > 0 || workout.completedSets > 0
    }

    private let color = Stat.physical.color

    var body: some View {
        let unit = model.settings.weightUnit.rawValue
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TextField("Workout name", text: $workout.name)
                        .font(.serif(40))
                        .foregroundStyle(.white)
                        .textFieldStyle(.plain)
                    HStack(spacing: 16) {
                        if !isExisting {
                            TimelineView(.periodic(from: .now, by: 1)) { context in
                                let s = Int(context.date.timeIntervalSince(started))
                                Label("\(s / 60):\(Day.pad(s % 60, 2))", systemImage: "stopwatch")
                            }
                        }
                        Label("\(workout.completedSets) sets", systemImage: "checkmark.circle")
                        Label("\(Int(workout.volume).grouped) \(unit)", systemImage: "scalemass")
                    }
                    .font(.mono(13))
                    .foregroundStyle(color)

                    ForEach($workout.exercises) { $exercise in
                        ExerciseCard(exercise: $exercise, unit: unit, color: color) {
                            workout.exercises.removeAll { $0.id == exercise.id }
                        }
                    }

                    Button {
                        picking = true
                    } label: {
                        Label("Add exercise", systemImage: "plus")
                    }
                    .buttonStyle(NeonButtonStyle(color: color))

                    Button("Finish workout") { finish() }
                        .buttonStyle(NeonButtonStyle(color: color, filled: true))
                        .disabled(workout.exercises.isEmpty)
                        .opacity(workout.exercises.isEmpty ? 0.4 : 1)
                }
                .padding(20)
                .frame(maxWidth: Theme.maxContentWidth)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppBackground(tint: color))
            .transparentNavBar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isExisting ? "Close" : "Discard") {
                        if isExisting || workout.completedSets == 0 { dismiss() } else { confirmDiscard = true }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Finish") { finish() }.disabled(workout.exercises.isEmpty)
                }
            }
            .confirmationDialog("Discard this workout?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Discard", role: .destructive) { dismiss() }
            }
            .sheet(isPresented: $picking) {
                ExercisePicker { name in
                    workout.exercises.append(ExerciseLog(name: name, sets: model.lastSets(for: name) ?? [SetLog(reps: 8, weight: 0)]))
                }
            }
        }
        .sheetSize(width: 640, height: 760)
    }

    private func finish() {
        if !isExisting { workout.durationSeconds = Int(Date().timeIntervalSince(started)) }
        if workout.name.trimmingCharacters(in: .whitespaces).isEmpty { workout.name = "Workout" }
        model.finishWorkout(workout)
        dismiss()
    }
}

private struct ExerciseCard: View {
    @Binding var exercise: ExerciseLog
    let unit: String
    let color: Color
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(exercise.name).font(.ui(17, .semibold)).foregroundStyle(.white)
                Spacer()
                Menu {
                    Button("Remove exercise", systemImage: "trash", role: .destructive, action: onRemove)
                } label: {
                    Image(systemName: "ellipsis").foregroundStyle(Theme.text2).frame(width: 30, height: 30)
                }
                .fixedSize()
            }
            HStack {
                MonoLabel("Set", size: 10).frame(width: 34, alignment: .leading)
                MonoLabel("Reps", size: 10).frame(maxWidth: .infinity)
                MonoLabel(unit, size: 10).frame(maxWidth: .infinity)
                MonoLabel("Done", size: 10).frame(width: 44)
            }
            ForEach($exercise.sets) { $set in
                let index = (exercise.sets.firstIndex { $0.id == set.id } ?? 0) + 1
                HStack {
                    Text("\(index)").font(.mono(14, .bold)).foregroundStyle(Theme.text2).frame(width: 34, alignment: .leading)
                    TextField("0", value: $set.reps, format: .number)
                        .numberPad()
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.plain)
                        .font(.mono(16, .semibold))
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
                        .frame(maxWidth: .infinity)
                    TextField("0", value: $set.weight, format: .number)
                        .decimalPad()
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.plain)
                        .font(.mono(16, .semibold))
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
                        .frame(maxWidth: .infinity)
                    Button {
                        set.done.toggle()
                        if set.done { Feedback.handle(.taskDone(combo: min(index, 10))) } else { Feedback.tap() }
                    } label: {
                        CheckBox(done: set.done, color: color)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 44)
                }
                .foregroundStyle(.white)
            }
            HStack {
                Button {
                    let last = exercise.sets.last ?? SetLog(reps: 8, weight: 0)
                    exercise.sets.append(SetLog(reps: last.reps, weight: last.weight))
                } label: {
                    Label("Add set", systemImage: "plus").font(.ui(14, .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(color)
                Spacer()
                if exercise.sets.count > 1 {
                    Button {
                        exercise.sets.removeLast()
                    } label: {
                        Label("Remove set", systemImage: "minus").font(.ui(14))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.text3)
                }
            }
        }
        .padding(16)
        .neonCard(color, active: !exercise.sets.isEmpty && exercise.sets.allSatisfy(\.done), radius: 18, glow: false)
    }
}

struct ExercisePicker: View {
    @Environment(\.dismiss) private var dismiss
    let onPick: (String) -> Void
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List {
                let custom = query.trimmingCharacters(in: .whitespaces)
                if !custom.isEmpty && !Exercises.library.contains(where: { $0.caseInsensitiveCompare(custom) == .orderedSame }) {
                    Button("Add “\(custom)”") {
                        onPick(custom)
                        dismiss()
                    }
                }
                ForEach(Exercises.library.filter { query.isEmpty || $0.localizedCaseInsensitiveContains(query) }, id: \.self) { name in
                    Button(name) {
                        onPick(name)
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            .searchable(text: $query, prompt: "Search or type a custom exercise")
            .navigationTitle("Add exercise")
            .transparentNavBar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .sheetSize(width: 440, height: 600)
    }
}

struct TemplateEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var template: WorkoutTemplate
    @State private var picking = false

    init(template: WorkoutTemplate) {
        _template = State(initialValue: template)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Push Day", text: $template.name)
                }
                Section("Exercises") {
                    ForEach(template.exercises, id: \.self) { name in
                        Text(name)
                    }
                    .onDelete { template.exercises.remove(atOffsets: $0) }
                    .onMove { template.exercises.move(fromOffsets: $0, toOffset: $1) }
                    Button {
                        picking = true
                    } label: {
                        Label("Add exercise", systemImage: "plus")
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle(template.builtIn ? "Edit template" : "Template")
            .transparentNavBar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        model.saveTemplate(template)
                        dismiss()
                    }
                    .disabled(template.name.trimmingCharacters(in: .whitespaces).isEmpty || template.exercises.isEmpty)
                }
            }
            .sheet(isPresented: $picking) {
                ExercisePicker { name in template.exercises.append(name) }
            }
        }
        .sheetSize(width: 480, height: 600)
    }
}
