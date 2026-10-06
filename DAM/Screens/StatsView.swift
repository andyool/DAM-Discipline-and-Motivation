import SwiftUI
import Charts

struct StatsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let snap = model.snap
        ScreenScroll(spacing: 24) {
            ScreenTitle(text: "Progress.")

            RadarChart(ratings: snap.ratings, ovr: snap.ovr, size: 230)
                .frame(maxWidth: .infinity)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach([Stat.social, .physical, .intellect, .discipline, .mental, .ambition]) { stat in
                    NavigationLink {
                        StatDetailView(stat: stat)
                    } label: {
                        StatTile(stat: stat, rating: snap.rating(stat))
                    }
                    .buttonStyle(PressableStyle())
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "XP · last 14 days") {
                    MonoLabel("\(snap.xpToday) today", color: model.theme.color)
                }
                XPChart(data: model.dailyXP(days: 14))
                    .frame(height: 170)
            }
            .padding(16)
            .glassCard()

            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Consistency") {
                    MonoLabel("Last 16 weeks", color: Theme.text3)
                }
                Heatmap(weeks: 16)
            }
            .padding(16)
            .glassCard()

            SectionHeader("Lifetime")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ValueTile(value: snap.totalXP.grouped, caption: "Total XP", color: model.theme.color, symbol: "bolt.fill")
                ValueTile(value: "\(snap.counters.tasksCompleted)", caption: "Tasks done", color: Stat.discipline.color, symbol: "checkmark")
                ValueTile(value: "\(snap.bestStreak)", caption: "Best streak", color: Theme.flame, symbol: "flame.fill")
                ValueTile(value: "\(snap.counters.perfectDays)", caption: "Perfect days", color: Stat.mental.color, symbol: "star.fill")
                ValueTile(value: (Double(snap.counters.focusMinutes) / 60).clean + "h", caption: "Locked in", color: Stat.ambition.color, symbol: "timer")
                ValueTile(value: "\(snap.counters.workouts)", caption: "Workouts", color: Stat.physical.color, symbol: "dumbbell.fill")
                ValueTile(value: "\(snap.counters.journalEntries)", caption: "Journal entries", color: Stat.mental.color, symbol: "book.closed.fill")
                ValueTile(value: "\(snap.counters.challenges)", caption: "Challenges", color: Stat.intellect.color, symbol: "bolt.fill")
            }
        }
        .hiddenNavBar()
    }
}

struct StatTile: View {
    let stat: Stat
    let rating: Int

    var body: some View {
        HStack(spacing: 14) {
            HexIcon(color: stat.color, size: 40, filled: false, lineWidth: 2)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(rating)")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Text(stat.name)
                    .font(.ui(14))
                    .foregroundStyle(stat.color)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .neonCard(stat.color, radius: 18)
    }
}

struct XPChart: View {
    let data: [Engine.DailyXP]

    var body: some View {
        Chart(data) { d in
            BarMark(x: .value("Day", Day.date(d.day), unit: .day),
                    y: .value("XP", d.xp))
                .foregroundStyle(by: .value("Stat", d.stat.name))
                .cornerRadius(3)
        }
        .chartForegroundStyleScale(domain: Stat.radarOrder.map(\.name), range: Stat.radarOrder.map(\.color))
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 2)) { _ in
                AxisValueLabel(format: .dateTime.day(), centered: true)
                    .foregroundStyle(Theme.text3)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                AxisValueLabel().foregroundStyle(Theme.text3)
            }
        }
        .overlay {
            if data.isEmpty {
                Text("Complete tasks to fill this up.")
                    .font(.ui(13))
                    .foregroundStyle(Theme.text3)
            }
        }
    }
}

struct Heatmap: View {
    @Environment(AppModel.self) private var model
    let weeks: Int

    var body: some View {
        let today = model.today
        let lastMonday = Day.weekStart(today)
        let first = Day.add(-(weeks - 1) * 7, to: lastMonday)
        let accent = model.theme.color
        HStack(alignment: .top, spacing: 4) {
            VStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { i in
                    Text(["M", "", "W", "", "F", "", ""][i])
                        .font(.mono(9))
                        .foregroundStyle(Theme.text3)
                        .frame(height: 14)
                }
            }
            ForEach(0..<weeks, id: \.self) { w in
                VStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { d in
                        let key = Day.add(w * 7 + d, to: first)
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(color(model.snap.state(key), accent: accent))
                            .frame(height: 14)
                            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(key == today ? Color.white : .clear, lineWidth: 1))
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func color(_ state: DayState, accent: Color) -> Color {
        switch state {
        case .perfect: return accent
        case .secured: return accent.opacity(0.6)
        case .partial: return accent.opacity(0.25)
        case .shielded: return Stat.social.color.opacity(0.45)
        case .missed: return Stat.discipline.color.opacity(0.28)
        case .pending: return Color.white.opacity(0.1)
        default: return Color.white.opacity(0.04)
        }
    }
}

// MARK: - Stat detail

struct StatDetailView: View {
    @Environment(AppModel.self) private var model
    let stat: Stat

    var body: some View {
        let snap = model.snap
        let history = model.ratingHistory(stat, days: 30)
        let change = (history.last?.rating ?? 0) - (history.first?.rating ?? 0)
        let habits = model.data.habits.filter { !$0.deleted && $0.stat == stat }
        let recent = model.data.entries.filter { !$0.deleted && $0.stat == stat && $0.xp > 0 }.sorted { $0.date > $1.date }.prefix(12)

        ScreenScroll(spacing: 22) {
            HStack(spacing: 18) {
                HexIcon(color: stat.color, size: 84, filled: false, symbol: stat.symbol, lineWidth: 3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(snap.rating(stat))")
                        .font(.system(size: 60, weight: .bold))
                        .foregroundStyle(.white)
                        .glow(stat.color, radius: 14)
                    Text(stat.name).font(.serif(32)).foregroundStyle(stat.color)
                }
            }
            Text(stat.tagline).font(.ui(16)).foregroundStyle(Theme.text2)

            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Last 30 days") {
                    MonoLabel((change >= 0 ? "+" : "") + "\(change)", color: change >= 0 ? Stat.physical.color : Stat.discipline.color, size: 12)
                }
                Chart(history) { p in
                    AreaMark(x: .value("Day", Day.date(p.day)), y: .value("Rating", p.rating))
                        .foregroundStyle(LinearGradient(colors: [stat.color.opacity(0.35), stat.color.opacity(0)], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("Day", Day.date(p.day)), y: .value("Rating", p.rating))
                        .foregroundStyle(stat.color)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.monotone)
                }
                .chartYScale(domain: 0...100)
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { _ in
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                        AxisValueLabel().foregroundStyle(Theme.text3)
                    }
                }
                .frame(height: 160)
            }
            .padding(16)
            .glassCard()

            HStack(spacing: 10) {
                ValueTile(value: (snap.statXP[stat] ?? 0).grouped, caption: "\(stat.name) XP", color: stat.color, symbol: "bolt.fill")
                ValueTile(value: "\(snap.counters.statActivities[stat] ?? 0)", caption: "Activities", color: stat.color, symbol: "checkmark")
            }

            VStack(alignment: .leading, spacing: 8) {
                MonoLabel("How to raise it", color: stat.color)
                Text(stat.improveTip).font(.ui(15)).foregroundStyle(.white)
                Text("Ratings grow with lifetime XP and the last 14 days of consistency. Neglect a stat and it slips.")
                    .font(.ui(13)).foregroundStyle(Theme.text3)
            }
            .padding(16)
            .neonCard(stat.color, radius: 18, glow: false)

            if !habits.isEmpty {
                SectionHeader("\(stat.name) tasks")
                ForEach(habits) { h in
                    HStack {
                        HexIcon(color: stat.color, size: 22)
                        Text(model.habitTitle(h, day: model.today)).font(.ui(15)).foregroundStyle(.white)
                        Spacer()
                        MonoLabel(h.scheduleLabel, size: 10)
                    }
                    .padding(12)
                    .glassCard(radius: 14)
                }
            }

            if !recent.isEmpty {
                SectionHeader("Recent")
                ForEach(Array(recent)) { e in
                    HStack {
                        Text(e.title).font(.ui(14)).foregroundStyle(.white).lineLimit(1)
                        Spacer()
                        MonoLabel(Day.short(e.day), size: 10)
                        MonoLabel("+\(e.xp)", color: stat.color, size: 11)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .navigationTitle("")
        .transparentNavBar()
    }
}
