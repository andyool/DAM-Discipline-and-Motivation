import SwiftUI

struct ProgramView: View {
    @Environment(AppModel.self) private var model
    @State private var week: Int? = nil
    @State private var newProgram = false

    var body: some View {
        Group {
            if let program = model.data.program {
                content(program)
            } else {
                ScreenScroll {
                    ScreenTitle(text: "Program.")
                    Text("No program yet.").font(.serif(28)).foregroundStyle(.white)
                    Button("Start a 60-day program") { newProgram = true }
                        .buttonStyle(NeonButtonStyle(color: .white, filled: true))
                }
            }
        }
        .transparentNavBar()
        .sheet(isPresented: $newProgram) { NewProgramSheet() }
    }

    private func content(_ program: Program) -> some View {
        let today = model.today
        let rawDay = Day.diff(program.startDay, today) + 1
        let day = min(max(rawDay, 1), program.length)
        let finished = program.ended || rawDay > program.length
        let weeks = Int(ceil(Double(program.length) / 7))
        let currentWeek = min((day - 1) / 7 + 1, weeks)
        let selectedWeek = week ?? currentWeek
        let stats = programStats(program)

        return ScreenScroll(spacing: 22) {
            VStack(alignment: .leading, spacing: 4) {
                ScreenTitle(text: "Program.")
                MonoLabel("60-day program #\(program.number) · \(program.intensity.name)", color: Theme.text2)
            }

            HexConstellation(size: 240, center: AnyView(
                VStack(spacing: 0) {
                    Text(finished ? "Done" : "Day \(day)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.white)
                        .glow(radius: 12, opacity: 0.5)
                    MonoLabel(finished ? "Program complete" : "of \(program.length)", color: Theme.text2)
                }
            ), lit: Set(program.focus))
            .frame(maxWidth: .infinity)

            HStack(spacing: 8) {
                ForEach(Array(Program.phases.enumerated()), id: \.offset) { i, phase in
                    let current = Program.phase(for: day) == i && !finished
                    VStack(spacing: 4) {
                        MonoLabel("Phase \(roman(i + 1))", color: current ? .white : Theme.text3, size: 10)
                        Text(phase.name).font(.ui(14, current ? .semibold : .regular))
                            .foregroundStyle(current ? .white : Theme.text2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(current ? 0.08 : 0.02)))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(current ? 0.6 : 0.08)))
                }
            }

            if finished {
                VStack(alignment: .leading, spacing: 10) {
                    Text("You finished the 60 days.").font(.serif(30)).foregroundStyle(.white)
                    Text("\(stats.secured) days secured. Level up the challenge: start your next program.")
                        .font(.ui(14)).foregroundStyle(Theme.text2)
                    Button("Start program #\(program.number + 1)") { newProgram = true }
                        .buttonStyle(NeonButtonStyle(color: .white, filled: true))
                }
                .padding(18)
                .neonCard(Stat.ambition.color, active: true)
            }

            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(1...weeks, id: \.self) { w in
                            PillTab(title: "Week \(w)", selected: w == selectedWeek) {
                                week = w
                                Feedback.tap()
                            }
                            .id(w)
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 2)
                }
                .scrollIndicators(.never)
                .onAppear { proxy.scrollTo(selectedWeek, anchor: .center) }
            }

            let weekStart = Day.add((selectedWeek - 1) * 7, to: program.startDay)
            let weekEnd = Day.add(min(selectedWeek * 7, program.length) - 1, to: program.startDay)
            Text("Week \(selectedWeek): \(Day.short(weekStart)) - \(Day.short(weekEnd))")
                .font(.ui(17, .medium))
                .foregroundStyle(.white)

            VStack(spacing: 12) {
                ForEach(model.programHabits) { habit in
                    ProgramHabitRow(habit: habit, weekStart: weekStart, days: Day.diff(weekStart, weekEnd) + 1,
                                    programDay: (selectedWeek - 1) * 7 + 1)
                }
            }

            SectionHeader("All 60 days")
            Honeycomb(program: program)
                .frame(maxWidth: .infinity)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ValueTile(value: "\(stats.secured)", caption: "Secured", color: Theme.flame, symbol: "flame.fill")
                ValueTile(value: "\(stats.rate)%", caption: "Completion", color: .white, symbol: "chart.pie.fill")
                ValueTile(value: stats.xp.grouped, caption: "XP earned", color: model.theme.color, symbol: "bolt.fill")
            }

            Menu {
                Button("Start a new program…") { newProgram = true }
            } label: {
                Label("Program options", systemImage: "ellipsis.circle")
                    .font(.ui(14))
                    .foregroundStyle(Theme.text3)
            }
            .fixedSize()
        }
    }

    private func programStats(_ p: Program) -> (secured: Int, rate: Int, xp: Int) {
        let from = Day.number(p.startDay)
        let to = min(Day.number(model.today), Day.number(p.endDay))
        guard to >= from else { return (0, 0, 0) }
        var secured = 0
        var done = 0
        var scheduled = 0
        for dn in from...to {
            let key = Day.key(dn)
            if model.snap.states[key]?.isWin == true { secured += 1 }
            if let r = model.snap.records[key] {
                done += r.done
                scheduled += r.scheduled
            }
        }
        let xp = model.data.entries.filter { e in
            guard !e.deleted, e.xp > 0 else { return false }
            let dn = Day.number(e.day)
            return dn >= from && dn <= to
        }.reduce(0) { $0 + $1.xp }
        let rate = scheduled > 0 ? Int(Double(done) / Double(scheduled) * 100) : 0
        return (secured, rate, xp)
    }
}

private struct ProgramHabitRow: View {
    @Environment(AppModel.self) private var model
    let habit: Habit
    let weekStart: String
    let days: Int
    let programDay: Int

    var body: some View {
        let today = Day.number(model.today)
        let dayKeys = (0..<days).map { Day.add($0, to: weekStart) }
        let scheduled = dayKeys.filter { habit.isScheduled(weekday: Day.weekday($0)) }
        let done = scheduled.filter { model.isDone(habit, day: $0) }.count
        let allDone = !scheduled.isEmpty && done == scheduled.count
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                HexIcon(color: habit.stat.color, size: 30, filled: allDone, symbol: allDone ? "checkmark" : nil)
                Text(habit.title(programDay: programDay + 3))
                    .font(.ui(16, .medium))
                    .foregroundStyle(.white)
                Spacer()
                MonoLabel("\(done)/\(scheduled.count)", color: habit.stat.color)
            }
            HStack(spacing: 6) {
                ForEach(dayKeys, id: \.self) { key in
                    let isScheduled = habit.isScheduled(weekday: Day.weekday(key))
                    let isDone = model.isDone(habit, day: key)
                    let future = Day.number(key) > today
                    Hexagon()
                        .fill(isDone ? habit.stat.color : Color.white.opacity(isScheduled && !future ? 0.08 : 0.02))
                        .overlay(Hexagon().stroke(habit.stat.color.opacity(isScheduled ? (future ? 0.25 : 0.6) : 0.1), lineWidth: 1))
                        .frame(width: 18, height: 18)
                        .shadow(color: isDone ? habit.stat.color.opacity(0.7) : .clear, radius: 4)
                }
            }
        }
        .padding(16)
        .neonCard(habit.stat.color, active: allDone, radius: 18)
    }
}

/// 60 hexagons, one per day, coloured by how the day went.
struct Honeycomb: View {
    @Environment(AppModel.self) private var model
    let program: Program
    var columns = 10
    var size: CGFloat = 28

    var body: some View {
        let rows = Int(ceil(Double(program.length) / Double(columns)))
        VStack(spacing: -size * 0.22) {
            ForEach(0..<rows, id: \.self) { r in
                HStack(spacing: size * 0.08) {
                    ForEach(0..<columns, id: \.self) { c in
                        let index = r * columns + c
                        if index < program.length {
                            cell(index)
                        }
                    }
                }
                .offset(x: r % 2 == 1 ? size * 0.54 : 0)
            }
        }
        .padding(.trailing, size * 0.54)
    }

    private func cell(_ index: Int) -> some View {
        let key = Day.add(index, to: program.startDay)
        let state = model.snap.state(key)
        let isToday = key == model.today
        let color: Color
        switch state {
        case .perfect: color = model.theme.color
        case .secured: color = model.theme.color.opacity(0.6)
        case .shielded: color = Stat.social.color.opacity(0.5)
        case .partial: color = model.theme.color.opacity(0.25)
        case .missed: color = Stat.discipline.color.opacity(0.25)
        default: color = Color.white.opacity(0.05)
        }
        return ZStack {
            Hexagon().fill(color)
            Hexagon().stroke(isToday ? Color.white : Color.white.opacity(0.1), lineWidth: isToday ? 2 : 1)
            if index == 0 || (index + 1) % 10 == 0 {
                Text("\(index + 1)").font(.mono(8, .bold)).foregroundStyle(Theme.text2)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: state.isWin ? model.theme.color.opacity(0.5) : .clear, radius: 4)
        .help(Day.long(key))
    }
}

struct NewProgramSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var intensity: Intensity = .lockedIn
    @State private var focus: Set<Stat> = Set(Stat.allCases)

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Intensity", selection: $intensity) {
                        ForEach(Intensity.allCases) { Text($0.name).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Text(intensity.blurb).font(.ui(13)).foregroundStyle(Theme.text2)
                } header: {
                    Text("Intensity")
                }
                Section {
                    ForEach(Stat.radarOrder) { stat in
                        Toggle(isOn: Binding(get: { focus.contains(stat) }, set: { on in
                            if on { focus.insert(stat) } else if focus.count > 3 { focus.remove(stat) }
                        })) {
                            StatChip(stat: stat, selected: focus.contains(stat), compact: true)
                        }
                        .tint(stat.color)
                    }
                } header: {
                    Text("Focus areas (min 3)")
                }
                Section {
                    Text("Your current program tasks are replaced by the new program's. Custom tasks, XP, levels and history stay.")
                        .font(.ui(13)).foregroundStyle(Theme.text2)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle("New program")
            .transparentNavBar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        model.startNewProgram(intensity: intensity, focus: Stat.radarOrder.filter { focus.contains($0) })
                        Feedback.secured()
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let p = model.data.program {
                    intensity = p.intensity
                    focus = Set(p.focus)
                }
            }
        }
        .sheetSize(width: 520, height: 640)
    }
}
