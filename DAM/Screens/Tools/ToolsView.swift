import SwiftUI

struct ToolsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let today = model.today
        let totals = model.nutritionTotals(on: today)
        let lastWorkout = model.workouts.first
        ScreenScroll(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                ScreenTitle(text: "Tools.")
                Text("Everything you need to level up, in one place.")
                    .font(.ui(15))
                    .foregroundStyle(Theme.text2)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                NavigationLink { FocusView() } label: {
                    ToolTile(title: "Lock In", subtitle: model.focus.phase == .idle ? "\(model.focusMinutesToday) min today" : "Session running",
                             symbol: "timer", color: Stat.ambition.color, live: model.focus.phase != .idle)
                }
                NavigationLink { BreatheView() } label: {
                    ToolTile(title: "Breathe", subtitle: "\(model.breathSessionsToday) sessions today", symbol: "wind", color: Stat.mental.color)
                }
                NavigationLink { JournalView() } label: {
                    ToolTile(title: "Journal",
                             subtitle: model.hasJournal(.morning, day: today) && model.hasJournal(.evening, day: today) ? "Both done today" :
                                (model.hasJournal(.morning, day: today) ? "Evening entry left" : "Start your morning entry"),
                             symbol: "book.closed.fill", color: Stat.mental.color)
                }
                NavigationLink { WorkoutsView() } label: {
                    ToolTile(title: "Lift", subtitle: lastWorkout.map { "Last: \($0.name) · \(Day.short($0.day))" } ?? "Log your first workout",
                             symbol: "dumbbell.fill", color: Stat.physical.color)
                }
                NavigationLink { NutritionView() } label: {
                    ToolTile(title: "Fuel", subtitle: "\(totals.calories.grouped) kcal · \(totals.protein)g protein",
                             symbol: "fork.knife", color: Stat.intellect.color)
                }
                NavigationLink { CoachView() } label: {
                    ToolTile(title: "Coach", subtitle: CoachAI.isAvailable ? "On-device AI coach" : "Tough love, on demand",
                             symbol: "bubble.left.and.bubble.right.fill", color: Stat.social.color)
                }
                NavigationLink { MirrorView() } label: {
                    ToolTile(title: "Mirror", subtitle: model.affirmedToday ? "Affirmed today" : "Look yourself in the eye",
                             symbol: "person.crop.square", color: Stat.discipline.color)
                }
                NavigationLink { ProgramView() } label: {
                    ToolTile(title: "Program", subtitle: model.snap.programDay.map { "Day \(min($0, 60)) of 60" } ?? "Start a program",
                             symbol: "hexagon.fill", color: .white)
                }
            }
            .buttonStyle(PressableStyle())

            QuoteCard(quote: Quotes.all[(Day.number(today) * 7 + 3) % Quotes.all.count])
        }
        .hiddenNavBar()
    }
}

struct ToolTile: View {
    let title: String
    let subtitle: String
    let symbol: String
    let color: Color
    var live = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HexIcon(color: color, size: 40, filled: live, symbol: symbol)
                Spacer()
                if live {
                    Circle().fill(color).frame(width: 8, height: 8).glow(color, radius: 6, opacity: 1)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.ui(18, .semibold)).foregroundStyle(.white)
                Text(subtitle)
                    .font(.ui(12))
                    .foregroundStyle(Theme.text2)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
        .padding(16)
        .neonCard(color, active: live, radius: 20)
    }
}

/// Standard header for tool screens.
struct ToolHeader: View {
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ScreenTitle(text: title)
            Text(subtitle)
                .font(.ui(15))
                .foregroundStyle(Theme.text2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
