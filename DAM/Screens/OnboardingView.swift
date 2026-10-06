import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var model

    @State private var step = 0
    @State private var name = ""
    @State private var answers: [Stat: Int] = [:]
    @State private var focus: Set<Stat> = Set(Stat.allCases)
    @State private var wake = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var intensity: Intensity = .lockedIn
    @State private var theme: EvolutionTheme = .hunter

    // 0 intro, 1 name, 2...7 assessment, 8 focus, 9 wake, 10 intensity, 11 theme, 12 build
    private let lastStep = 12
    private var questionIndex: Int? { (2...7).contains(step) ? step - 2 : nil }

    var body: some View {
        VStack(spacing: 0) {
            if step > 0 && step < lastStep {
                header
            }
            content
                .id(step)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)))
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .animation(.spring(duration: 0.5, bounce: 0.15), value: step)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Button {
                step -= 1
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.text2)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            GlowBar(progress: Double(step) / Double(lastStep), color: .white, height: 6)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .frame(maxWidth: 600)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case 0: intro
        case 1: nameStep
        case 8: focusStep
        case 9: wakeStep
        case 10: intensityStep
        case 11: themeStep
        case 12: BuildProgramStep(name: name, answers: answers, focus: Array(focus), intensity: intensity,
                                  wakeMinutes: wakeMinutes, theme: theme)
        default:
            if let i = questionIndex { questionStep(Assessment.questions[i]) }
        }
    }

    private var wakeMinutes: Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: wake)
        return (c.hour ?? 7) * 60 + (c.minute ?? 0)
    }

    private func next() {
        Feedback.tap()
        step += 1
    }

    // MARK: Steps

    private var intro: some View {
        VStack(spacing: 28) {
            Spacer()
            Text("DAM.")
                .font(.serif(84))
                .foregroundStyle(.white)
                .glow(radius: 18, opacity: 0.5)
            MonoLabel("Discipline & Motivation", color: Theme.text2, size: 12)
            Spacer()
            HexConstellation(size: 200, center: AnyView(EmptyView()))
            Spacer()
            (Text("Reach your potential and ") + Text("transform your life").bold() + Text(" in the next ") + Text("60 days.").bold())
                .font(.ui(24))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .glow(radius: 10, opacity: 0.3)
                .padding(.horizontal, 30)
            Button("Begin", action: next)
                .buttonStyle(NeonButtonStyle(color: .white, filled: true))
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
        }
    }

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer()
            Text("What do they\ncall you?")
                .font(.serif(46))
                .foregroundStyle(.white)
            TextField("", text: $name, prompt: Text("Your name").foregroundStyle(Theme.text3))
                .font(.ui(28, .medium))
                .foregroundStyle(.white)
                .textFieldStyle(.plain)
                .padding(.vertical, 12)
                .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.3)).frame(height: 1) }
                .onSubmit { if !name.trimmingCharacters(in: .whitespaces).isEmpty { next() } }
            Spacer()
            Button("Continue", action: next)
                .buttonStyle(NeonButtonStyle(color: .white, filled: true))
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
        }
        .padding(30)
    }

    private func questionStep(_ q: AssessmentQuestion) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer()
            HStack(spacing: 8) {
                HexIcon(color: q.stat.color, size: 22, filled: true)
                MonoLabel(q.stat.name, color: q.stat.color, size: 12)
            }
            Text(q.question)
                .font(.serif(40))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Spacer().frame(height: 10)
            ForEach(Array(q.options.enumerated()), id: \.offset) { i, option in
                let selected = answers[q.stat] == i
                Button {
                    answers[q.stat] = i
                    Feedback.tap()
                    Task {
                        try? await Task.sleep(nanoseconds: 280_000_000)
                        step += 1
                    }
                } label: {
                    HStack {
                        Text(option).font(.ui(17, .medium)).foregroundStyle(.white)
                        Spacer()
                        if selected { Image(systemName: "checkmark").foregroundStyle(q.stat.color) }
                    }
                    .padding(18)
                    .neonCard(q.stat.color, active: selected, radius: 16)
                }
                .buttonStyle(PressableStyle())
            }
            Spacer()
        }
        .padding(30)
    }

    private var focusStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("What do you want\nto level up?")
                .font(.serif(42))
                .foregroundStyle(.white)
                .padding(.top, 20)
            Text("Pick at least 3 areas. Your program builds tasks for each one.")
                .font(.ui(15))
                .foregroundStyle(Theme.text2)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(Stat.radarOrder) { stat in
                    let on = focus.contains(stat)
                    Button {
                        if on { if focus.count > 3 { focus.remove(stat) } } else { focus.insert(stat) }
                        Feedback.tap()
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            HexIcon(color: stat.color, size: 34, filled: on, symbol: stat.symbol)
                            Text(stat.name).font(.ui(17, .semibold)).foregroundStyle(.white)
                            Text(stat.tagline).font(.ui(12)).foregroundStyle(Theme.text2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
                        .padding(16)
                        .neonCard(stat.color, active: on, radius: 18)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            Spacer()
            Button("Continue", action: next)
                .buttonStyle(NeonButtonStyle(color: .white, filled: true))
        }
        .padding(24)
    }

    private var wakeStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            HStack(spacing: 8) {
                HexIcon(color: Stat.discipline.color, size: 22, filled: true)
                MonoLabel("Discipline", color: Stat.discipline.color, size: 12)
            }
            Text("What time will you\nwake up?")
                .font(.serif(42))
                .foregroundStyle(.white)
            Text("This becomes your first task every morning. Pick a time you can hit consistently, then own it.")
                .font(.ui(15))
                .foregroundStyle(Theme.text2)
            HStack {
                Spacer()
                wakePicker
                Spacer()
            }
            .padding(.vertical, 10)
            Spacer()
            Button("Continue", action: next)
                .buttonStyle(NeonButtonStyle(color: .white, filled: true))
        }
        .padding(30)
    }

    @ViewBuilder
    private var wakePicker: some View {
        #if os(iOS)
        DatePicker("Wake up", selection: $wake, displayedComponents: .hourAndMinute)
            .datePickerStyle(.wheel)
            .labelsHidden()
            .environment(\.colorScheme, .dark)
        #else
        DatePicker("Wake up", selection: $wake, displayedComponents: .hourAndMinute)
            .datePickerStyle(.stepperField)
            .labelsHidden()
            .font(.ui(28))
        #endif
    }

    private var intensityStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose your\nintensity.")
                .font(.serif(42))
                .foregroundStyle(.white)
                .padding(.top, 20)
            ForEach(Intensity.allCases) { level in
                let selected = intensity == level
                let color: Color = level == .steady ? Stat.physical.color : (level == .lockedIn ? Stat.social.color : Stat.discipline.color)
                let count = ProgramBuilder.habits(for: Program(startDay: model.today, intensity: level, focus: Array(focus)), wakeMinutes: wakeMinutes).count
                Button {
                    intensity = level
                    Feedback.tap()
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(level.name).font(.serif(30)).foregroundStyle(.white)
                            Spacer()
                            MonoLabel("\(count) tasks / day", color: color)
                        }
                        Text(level.blurb).font(.ui(14)).foregroundStyle(Theme.text2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(18)
                    .neonCard(color, active: selected, radius: 18)
                }
                .buttonStyle(PressableStyle())
            }
            Spacer()
            Button("Continue", action: next)
                .buttonStyle(NeonButtonStyle(color: .white, filled: true))
        }
        .padding(24)
    }

    private var themeStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Choose your path.")
                .font(.serif(42))
                .foregroundStyle(.white)
                .padding(.top, 20)
            Text("Your avatar evolves through 10 forms as you level up. You can change this later.")
                .font(.ui(15))
                .foregroundStyle(Theme.text2)
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(EvolutionTheme.allCases) { t in
                        let selected = theme == t
                        Button {
                            theme = t
                            Feedback.tap()
                        } label: {
                            HStack(spacing: 16) {
                                SigilView(stage: selected ? 5 : 2, theme: t, size: 78, animated: selected)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(t.name).font(.serif(28)).foregroundStyle(.white)
                                    Text(t.tagline).font(.ui(13)).foregroundStyle(Theme.text2)
                                    Text("\(t.forms[0]) → \(t.forms[4]) → \(t.forms[9])")
                                        .font(.mono(10))
                                        .foregroundStyle(t.color)
                                        .lineLimit(2)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(14)
                            .neonCard(t.color, active: selected, radius: 18)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(.vertical, 6)
            }
            .scrollIndicators(.never)
            Button("Build my program", action: next)
                .buttonStyle(NeonButtonStyle(color: .white, filled: true))
        }
        .padding(24)
    }
}

// MARK: - Program reveal

private struct BuildProgramStep: View {
    @Environment(AppModel.self) private var model
    let name: String
    let answers: [Stat: Int]
    let focus: [Stat]
    let intensity: Intensity
    let wakeMinutes: Int
    let theme: EvolutionTheme

    @State private var analyzing = true
    @State private var progress = 0.0
    @State private var status = "Analyzing your answers"

    private var preview: [Habit] {
        ProgramBuilder.habits(for: Program(startDay: model.today, intensity: intensity, focus: focus), wakeMinutes: wakeMinutes)
    }

    private var ratings: [Stat: Int] {
        Dictionary(uniqueKeysWithValues: Stat.allCases.map { ($0, Assessment.baseline(answer: answers[$0] ?? 1)) })
    }

    var body: some View {
        Group {
            if analyzing {
                VStack(spacing: 26) {
                    Spacer()
                    HexConstellation(size: 190, center: AnyView(ProgressCounter(progress: progress)))
                    Text(status)
                        .font(.ui(18, .medium))
                        .foregroundStyle(Theme.text2)
                        .contentTransition(.opacity)
                    GlowBar(progress: progress, color: .white, height: 6)
                        .frame(maxWidth: 260)
                    Spacer()
                }
                .padding(30)
            } else {
                ready
            }
        }
        .task {
            let steps = ["Analyzing your answers", "Calibrating your stats", "Building your 60-day program", "Locking it in"]
            for (i, s) in steps.enumerated() {
                status = s
                withAnimation(.easeInOut(duration: 0.6)) { progress = Double(i + 1) / Double(steps.count) }
                try? await Task.sleep(nanoseconds: 650_000_000)
            }
            Feedback.secured()
            withAnimation(.spring(duration: 0.6)) { analyzing = false }
        }
    }

    private var ready: some View {
        ScrollView {
            VStack(spacing: 20) {
                (Text("Your ") + Text("60-Day program").bold() + Text(" is ready"))
                    .font(.ui(22))
                    .foregroundStyle(.white)
                    .glow(radius: 8, opacity: 0.3)
                    .padding(.top, 30)
                HexConstellation(size: 170, center: AnyView(
                    Text("Day 1").font(.system(size: 40, weight: .bold)).foregroundStyle(.white).glow(radius: 10, opacity: 0.5)
                ))
                VStack(alignment: .leading, spacing: 10) {
                    MonoLabel("Your starting stats", color: Theme.text2)
                    RadarChart(ratings: ratings, ovr: Int(Double(ratings.values.reduce(0, +)) / 6.0 + 0.5), size: 170)
                        .frame(maxWidth: .infinity)
                    Text("Everyone starts somewhere. Watch these climb.")
                        .font(.ui(13))
                        .foregroundStyle(Theme.text3)
                        .frame(maxWidth: .infinity)
                }
                VStack(alignment: .leading, spacing: 10) {
                    MonoLabel("Day 1 tasks", color: Theme.text2)
                    ForEach(preview) { h in
                        HStack(spacing: 12) {
                            HexIcon(color: h.stat.color, size: 26)
                            Text(h.title(programDay: 1)).font(.ui(16, .medium)).foregroundStyle(.white)
                            Spacer()
                        }
                        .padding(14)
                        .neonCard(h.stat.color, radius: 16)
                    }
                }
                Button("Start Day 1") {
                    model.completeOnboarding(name: name, answers: answers, focus: focus, intensity: intensity,
                                             wakeMinutes: wakeMinutes, theme: theme)
                    Task {
                        _ = await Reminders.requestAuthorization()
                        await Reminders.reschedule(model)
                    }
                }
                .buttonStyle(NeonButtonStyle(color: .white, filled: true))
                .padding(.vertical, 20)
            }
            .padding(.horizontal, 24)
        }
        .scrollIndicators(.never)
    }
}

private struct ProgressCounter: View {
    let progress: Double

    var body: some View {
        Text("\(Int(progress * 100))%")
            .font(.system(size: 34, weight: .bold))
            .foregroundStyle(.white)
            .contentTransition(.numericText())
            .glow(radius: 10, opacity: 0.5)
    }
}

/// Six stat-coloured hexagons arranged in a hexagon, with something in the middle.
struct HexConstellation: View {
    var size: CGFloat = 200
    var center: AnyView
    var lit: Set<Stat> = Set(Stat.allCases)

    @State private var appear = false

    var body: some View {
        ZStack {
            Hexagon()
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                .frame(width: size * 0.84, height: size * 0.84)
            ForEach(Array(Stat.radarOrder.enumerated()), id: \.offset) { i, stat in
                HexIcon(color: stat.color, size: size * 0.2, filled: false, lineWidth: 2)
                    .opacity(lit.contains(stat) ? 1 : 0.25)
                    .offset(appear ? Hexagon.vertex(i, radius: size * 0.42) : .zero)
                    .scaleEffect(appear ? 1 : 0.2)
                    .animation(.spring(duration: 0.7, bounce: 0.4).delay(Double(i) * 0.07), value: appear)
            }
            center
        }
        .frame(width: size, height: size)
        .onAppear { appear = true }
    }
}
