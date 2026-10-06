import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var selectedDay: String = Day.today()
    @State private var editing: Habit? = nil
    @State private var addingTask = false

    private var day: String { selectedDay }
    private var editable: Bool { model.canEdit(day) }

    var body: some View {
        let snap = model.snap
        let tasks = model.tasks(for: day)
        ScreenScroll(spacing: 20) {
            HStack(alignment: .center) {
                ScreenTitle(text: "Home.")
                Spacer()
                StreakChip(streak: snap.streak, shields: snap.shields, multiplier: snap.multiplier)
            }

            AvatarHeader()

            WeekStrip(selected: $selectedDay, today: snap.today, accent: model.theme.color) { model.snap.state($0) }

            HStack(alignment: .firstTextBaseline) {
                Text(Day.headline(day))
                    .font(.ui(18, .medium))
                    .foregroundStyle(.white)
                Spacer()
                let done = tasks.filter(\.done).count
                MonoLabel("\(done)/\(tasks.count) done", color: done == tasks.count && !tasks.isEmpty ? Theme.flame : Theme.text3)
            }
            .padding(.top, 4)

            if day == snap.today, let program = model.data.program {
                ProgramBanner(day: program.ended ? program.length + 1 : (snap.programDay ?? 1), intensity: program.intensity)
            }

            if !editable {
                Label("Past days are locked. You can still check off yesterday.", systemImage: "lock.fill")
                    .font(.ui(13))
                    .foregroundStyle(Theme.text3)
            }

            VStack(spacing: 12) {
                ForEach(tasks) { item in
                    TaskCard(item: item, xpShown: Int((Double(item.xp) * snap.multiplier).rounded()), editable: editable) {
                        withAnimation(.spring(duration: 0.4, bounce: 0.35)) { model.toggle(item, day: day) }
                    }
                    .contextMenu { contextMenu(for: item) }
                }
            }

            if tasks.isEmpty {
                VStack(spacing: 8) {
                    Text("Nothing scheduled.").font(.serif(28)).foregroundStyle(.white)
                    Text("Add a task, or accept a daily challenge.").font(.ui(14)).foregroundStyle(Theme.text2)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .glassCard()
            }

            Button {
                addingTask = true
            } label: {
                Label("Add task", systemImage: "plus")
                    .font(.ui(15, .medium))
                    .foregroundStyle(Theme.text2)
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [5, 5])))
            }
            .buttonStyle(PressableStyle())

            if day == snap.today && snap.todaySecured {
                SecuredBanner(streak: snap.streak, perfect: snap.states[snap.today] == .perfect)
            }

            CoachCard()
            QuoteCard(quote: Quotes.of(day: snap.today))
        }
        .hiddenNavBar()
        .sheet(isPresented: $addingTask) {
            HabitEditor(habit: model.newHabit(), isNew: true)
        }
        .sheet(item: $editing) { habit in
            HabitEditor(habit: habit, isNew: false)
        }
        .onChange(of: model.snap.today) { _, today in selectedDay = today }
    }

    @ViewBuilder
    private func contextMenu(for item: TaskItem) -> some View {
        if case .habit(let id) = item.source, let habit = model.data.habits.first(where: { $0.id == id }) {
            Button {
                editing = habit
            } label: {
                Label("Edit task", systemImage: "pencil")
            }
            Button(role: .destructive) {
                model.deleteHabit(habit)
            } label: {
                Label("Delete task", systemImage: "trash")
            }
        }
        if case .challenge(let key) = item.source {
            Button(role: .destructive) {
                model.setAccepted(key, accepted: false)
            } label: {
                Label("Drop challenge", systemImage: "xmark")
            }
        }
    }
}

// MARK: - Avatar header

struct AvatarHeader: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let snap = model.snap
        let color = model.theme.color
        VStack(spacing: 6) {
            NavigationLink {
                EvolutionView()
            } label: {
                SigilView(stage: snap.stage, theme: model.theme, size: 210)
            }
            .buttonStyle(.plain)
            Text(model.formName)
                .font(.serif(26))
                .foregroundStyle(Theme.text2)
            Text("Level \(snap.level.level)")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .glow(radius: 12, opacity: 0.45)
            NavigationLink {
                RankLadderView()
            } label: {
                HStack(spacing: 8) {
                    RankBadge(rank: snap.rank, size: 20, glow: false)
                    Text(snap.rank.code)
                        .font(.mono(15, .semibold))
                        .tracking(2)
                        .foregroundStyle(snap.rank.tier.light)
                }
            }
            .buttonStyle(.plain)
            VStack(spacing: 8) {
                GlowBar(progress: snap.level.progress, color: color, height: 10)
                HStack {
                    MonoLabel("LVL \(snap.level.level)", color: Theme.text2)
                    Spacer()
                    MonoLabel("\(snap.level.remaining) XP to next level", color: color)
                    Spacer()
                    MonoLabel("LVL \(snap.level.level + 1)", color: Theme.text2)
                }
            }
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity)
    }
}

struct StreakChip: View {
    let streak: Int
    let shields: Int
    let multiplier: Double

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(LinearGradient(colors: [.yellow, Theme.flame], startPoint: .top, endPoint: .bottom))
                Text("\(streak)")
                    .font(.mono(16, .bold))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
            if multiplier > 1.0 {
                Text(StreakBonus.label(multiplier))
                    .font(.mono(11, .bold))
                    .foregroundStyle(Theme.flame)
            }
            if shields > 0 {
                HStack(spacing: 2) {
                    ForEach(0..<shields, id: \.self) { _ in
                        Image(systemName: "shield.fill").font(.system(size: 11)).foregroundStyle(Stat.social.color)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(Theme.flame.opacity(streak > 0 ? 0.12 : 0.04)))
        .overlay(Capsule().strokeBorder(Theme.flame.opacity(streak > 0 ? 0.7 : 0.2), lineWidth: 1))
        .shadow(color: Theme.flame.opacity(streak > 0 ? 0.4 : 0), radius: 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(streak) day streak")
    }
}

// MARK: - Week strip

struct WeekStrip: View {
    @Binding var selected: String
    let today: String
    let accent: Color
    let state: (String) -> DayState

    var body: some View {
        let start = Day.weekStart(today)
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { i in
                let day = Day.add(i, to: start)
                Button {
                    if Day.number(day) <= Day.number(today) {
                        selected = day
                        Feedback.tap()
                    }
                } label: {
                    VStack(spacing: 8) {
                        DayCircle(state: state(day), isToday: day == today, isSelected: day == selected, accent: accent)
                        Text(Day.shortWeekdays[Day.weekday(day) - 1])
                            .font(.mono(12, day == selected ? .bold : .regular))
                            .foregroundStyle(day == selected ? .white : Theme.text3)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct DayCircle: View {
    let state: DayState
    let isToday: Bool
    let isSelected: Bool
    let accent: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(fill)
            Circle()
                .strokeBorder(stroke, lineWidth: isSelected ? 2 : 1.2)
            icon
        }
        .frame(width: 40, height: 40)
        .shadow(color: glow, radius: isSelected ? 10 : 6)
    }

    private var fill: Color {
        switch state {
        case .perfect: return accent.opacity(0.35)
        case .secured: return accent.opacity(0.2)
        case .shielded: return Stat.social.color.opacity(0.15)
        case .missed: return Stat.discipline.color.opacity(0.08)
        default: return Color.white.opacity(0.03)
        }
    }

    private var stroke: Color {
        if isSelected { return .white }
        switch state {
        case .perfect, .secured: return accent.opacity(0.9)
        case .shielded: return Stat.social.color.opacity(0.7)
        case .missed: return Stat.discipline.color.opacity(0.35)
        case .future: return Color.white.opacity(0.08)
        default: return Color.white.opacity(0.22)
        }
    }

    private var glow: Color {
        if isSelected { return .white.opacity(0.45) }
        return state.isWin ? accent.opacity(0.6) : .clear
    }

    @ViewBuilder
    private var icon: some View {
        switch state {
        case .perfect, .secured:
            Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(state == .perfect ? .white : accent)
        case .shielded:
            Image(systemName: "shield.fill").font(.system(size: 12)).foregroundStyle(Stat.social.color)
        case .missed:
            Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Stat.discipline.color.opacity(0.6))
        case .partial:
            Circle().fill(accent.opacity(0.7)).frame(width: 6, height: 6)
        default:
            EmptyView()
        }
    }
}

// MARK: - Task card

struct TaskCard: View {
    let item: TaskItem
    let xpShown: Int
    let editable: Bool
    let onToggle: () -> Void

    @State private var burst = 0
    @State private var floatToken: UUID? = nil

    var body: some View {
        Button {
            guard editable else { return }
            let completing = !item.done
            onToggle()
            if completing {
                burst += 1
                let token = UUID()
                floatToken = token
                Task {
                    try? await Task.sleep(nanoseconds: 1_200_000_000)
                    if floatToken == token { floatToken = nil }
                }
            }
        } label: {
            HStack(spacing: 14) {
                HexIcon(color: item.stat.color, size: 34, filled: item.done, symbol: item.done ? "checkmark" : nil)
                    .scaleEffect(item.done ? 1.06 : 1)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.ui(16, .medium))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        MonoLabel(item.isChallenge ? "Challenge" : item.stat.name, color: item.stat.color.opacity(0.9), size: 10)
                        MonoLabel("+\(xpShown) XP", color: Theme.text3, size: 10)
                        if !item.isChallenge && item.schedule != "Every day" {
                            MonoLabel(item.schedule, color: Theme.text3, size: 10)
                        }
                    }
                }
                Spacer(minLength: 8)
                CheckBox(done: item.done, color: item.stat.color)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .neonCard(item.stat.color, active: item.done, radius: 18)
            .overlay {
                ParticleBurst(trigger: burst, colors: [item.stat.color, .white, item.stat.color], count: 20, spread: 110)
            }
            .overlay(alignment: .trailing) {
                if let floatToken {
                    FloatingText(text: "+\(xpShown) XP", color: item.stat.color)
                        .id(floatToken)
                        .padding(.trailing, 56)
                }
            }
        }
        .buttonStyle(PressableStyle())
        .opacity(editable ? 1 : 0.8)
        .accessibilityLabel("\(item.title), \(item.done ? "done" : "not done")")
    }
}

struct CheckBox: View {
    let done: Bool
    let color: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(done ? color.opacity(0.35) : Color.white.opacity(0.03))
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(done ? color : Color.white.opacity(0.45), lineWidth: 1.5)
            if done {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.white)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: 26, height: 26)
    }
}

// MARK: - Cards

struct ProgramBanner: View {
    let day: Int
    let intensity: Intensity

    var body: some View {
        NavigationLink {
            ProgramView()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.1), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: min(Double(day) / 60, 1))
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .glow(radius: 6, opacity: 0.6)
                    Text("\(min(day, 60))").font(.mono(13, .bold)).foregroundStyle(.white)
                }
                .frame(width: 46, height: 46)
                VStack(alignment: .leading, spacing: 3) {
                    MonoLabel(day > 60 ? "Program complete" : "60-day program · \(intensity.name)", color: Theme.text2, size: 10)
                    Text(day > 60 ? "Claim your next program" : "Day \(day) of 60 · Phase \(roman(Program.phase(for: day) + 1)): \(Program.phases[Program.phase(for: day)].name)")
                        .font(.ui(15, .medium))
                        .foregroundStyle(.white)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.text3)
            }
            .padding(14)
            .glassCard(radius: 18)
        }
        .buttonStyle(PressableStyle())
    }
}

struct SecuredBanner: View {
    let streak: Int
    let perfect: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "flame.fill")
                .font(.system(size: 26))
                .foregroundStyle(LinearGradient(colors: [.yellow, Theme.flame], startPoint: .top, endPoint: .bottom))
                .glow(Theme.flame, radius: 10, opacity: 0.9)
            VStack(alignment: .leading, spacing: 2) {
                MonoLabel(perfect ? "Perfect day" : "Day secured", color: Theme.flame, size: 12)
                Text(perfect ? "Every task done. Legendary." : "Streak protected. Finish the rest for a perfect day.")
                    .font(.ui(14))
                    .foregroundStyle(Theme.text2)
            }
            Spacer()
        }
        .padding(16)
        .neonCard(Theme.flame, active: perfect, radius: 18)
    }
}

struct CoachCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationLink {
            CoachView()
        } label: {
            HStack(alignment: .top, spacing: 14) {
                HexIcon(color: model.theme.color, size: 34, filled: false, symbol: "bubble.left.fill")
                VStack(alignment: .leading, spacing: 6) {
                    MonoLabel("Coach", color: model.theme.color, size: 11)
                    Text(CoachBrain.insight(model))
                        .font(.ui(15))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Talk to your coach →")
                        .font(.ui(13, .medium))
                        .foregroundStyle(Theme.text3)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .neonCard(model.theme.color, radius: 18, glow: false)
        }
        .buttonStyle(PressableStyle())
    }
}

struct QuoteCard: View {
    let quote: Quote

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            MonoLabel("Quote of the day", color: Theme.text3, size: 10)
            Text("“\(quote.text)”")
                .font(.serifItalic(24))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Text("— \(quote.author)")
                .font(.ui(13))
                .foregroundStyle(Theme.text2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard(radius: 18)
    }
}
