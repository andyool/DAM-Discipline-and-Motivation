import SwiftUI

struct ProfileView: View {
    @Environment(AppModel.self) private var model
    @State private var showCard = false

    var body: some View {
        let snap = model.snap
        let color = model.theme.color
        let name = model.profile.name.isEmpty ? "You" : model.profile.name
        ScreenScroll(spacing: 22) {
            HStack {
                ScreenTitle(text: "Profile.")
                Spacer()
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.text2)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.white.opacity(0.06)))
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 10) {
                ZStack {
                    HexIcon(color: color, size: 96, filled: false, lineWidth: 3)
                    Text(String(name.prefix(1)).uppercased())
                        .font(.serif(46))
                        .foregroundStyle(.white)
                }
                Text(name)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
                    .glow(radius: 10, opacity: 0.35)
                MonoLabel("\(model.formName) · since \(Day.short(model.profile.startDay))", color: Theme.text3)
                Button("View progress card") { showCard = true }
                    .buttonStyle(NeonButtonStyle(color: color))
                    .frame(maxWidth: 280)
                    .padding(.top, 6)
            }
            .frame(maxWidth: .infinity)

            RankProgressCard()

            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Achievements") {
                    NavigationLink("See all") { AchievementsView() }
                        .font(.ui(14))
                        .foregroundStyle(Theme.text2)
                }
                let unlocked = Achievements.all.filter { model.achievementTier($0) > 0 }
                let shown = Array((unlocked + Achievements.all.filter { model.achievementTier($0) == 0 }).prefix(6))
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 18) {
                    ForEach(shown) { def in
                        AchievementCell(def: def, tier: model.achievementTier(def))
                    }
                }
                MonoLabel("\(unlocked.count) of \(Achievements.all.count) unlocked", color: Theme.text3, size: 10)
                    .frame(maxWidth: .infinity)
            }

            NavigationLink {
                EvolutionView()
            } label: {
                HStack(spacing: 16) {
                    SigilView(stage: snap.stage, theme: model.theme, size: 70, animated: false)
                    VStack(alignment: .leading, spacing: 4) {
                        MonoLabel("Evolution · \(model.theme.name)", color: color, size: 10)
                        Text(model.formName).font(.serif(28)).foregroundStyle(.white)
                        if let next = Evolution.nextStageLevel(after: snap.stage) {
                            Text("Next form at level \(next)").font(.ui(13)).foregroundStyle(Theme.text2)
                        } else {
                            Text("Final form reached.").font(.ui(13)).foregroundStyle(Theme.text2)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(Theme.text3)
                }
                .padding(16)
                .neonCard(color, radius: 20, glow: false)
            }
            .buttonStyle(PressableStyle())

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ValueTile(value: "\(snap.streak)", caption: "Current streak", color: Theme.flame, symbol: "flame.fill")
                ValueTile(value: "\(snap.bestStreak)", caption: "Best streak", color: Theme.flame, symbol: "trophy.fill")
                ValueTile(value: snap.totalXP.grouped, caption: "Total XP", color: color, symbol: "bolt.fill")
                ValueTile(value: "\(snap.counters.securedDays)", caption: "Days secured", color: Stat.physical.color, symbol: "checkmark.seal.fill")
            }
        }
        .hiddenNavBar()
        .sheet(isPresented: $showCard) {
            ProgressCardSheet()
        }
    }
}

struct AchievementCell: View {
    let def: AchievementDef
    let tier: Int

    var body: some View {
        VStack(spacing: 6) {
            AchievementBadge(symbol: def.symbol, stat: def.stat, tier: tier, size: 64)
            Text(tier > 0 ? "\(def.name) \(roman(tier))".uppercased() : def.name.uppercased())
                .font(.mono(10, .semibold))
                .foregroundStyle(tier > 0 ? .white : Theme.text3)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
    }
}

// MARK: - Rank progress

struct RankProgressCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let snap = model.snap
        let current = snap.rank
        let prev = Ranks.previous(before: current)
        let next = Ranks.next(after: current)
        let afterNext = next.flatMap { Ranks.next(after: $0) }
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Rank progress") {
                NavigationLink("See all") { RankLadderView() }
                    .font(.ui(14))
                    .foregroundStyle(Theme.text2)
            }
            HStack(alignment: .bottom, spacing: 4) {
                if let prev {
                    rankColumn(prev, size: 40, label: prev.code, dim: true)
                }
                rankColumn(current, size: 74, label: current.code, dim: false, highlight: true)
                if let next {
                    rankColumn(next, size: 40, label: "???", dim: true, locked: true)
                }
                if let afterNext {
                    rankColumn(afterNext, size: 34, label: "???", dim: true, locked: true)
                }
            }
            .frame(maxWidth: .infinity)
            if let left = snap.levelsToNextRank {
                Text("\(left) level\(left == 1 ? "" : "s") to next rank")
                    .font(.ui(14))
                    .foregroundStyle(Theme.text2)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .glassCard()
    }

    private func rankColumn(_ rank: Rank, size: CGFloat, label: String, dim: Bool, locked: Bool = false, highlight: Bool = false) -> some View {
        VStack(spacing: 8) {
            RankBadge(rank: rank, size: size, locked: locked, glow: highlight)
                .opacity(dim && !locked ? 0.7 : 1)
            Text(label)
                .font(.mono(highlight ? 15 : 10, highlight ? .bold : .regular))
                .foregroundStyle(highlight ? rank.tier.light : Theme.text3)
                .glow(highlight ? rank.tier.light : .clear, radius: 6)
        }
        .frame(maxWidth: .infinity)
    }
}

struct RankLadderView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let snap = model.snap
        let currentIndex = Ranks.index(forLevel: snap.level.level)
        let dates = model.levelDates()
        ScrollViewReader { proxy in
            ScreenScroll(spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    ScreenTitle(text: "Ranks.")
                    if let left = snap.levelsToNextRank {
                        (Text("\(left) more level\(left == 1 ? "" : "s")").bold() + Text(" until the next rank"))
                            .font(.ui(18))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.bottom, 26)

                ForEach(Array(Ranks.all.enumerated()), id: \.offset) { i, rank in
                    let reached = i <= currentIndex
                    let isCurrent = i == currentIndex
                    HStack(spacing: 18) {
                        RankBadge(rank: rank, size: isCurrent ? 84 : 58, locked: !reached, glow: isCurrent)
                            .frame(width: 110)
                        VStack(alignment: .leading, spacing: 3) {
                            if isCurrent {
                                Text("Current rank").font(.ui(13, .medium)).foregroundStyle(rank.tier.light)
                            } else if reached, let date = dates[rank.minLevel] {
                                Text("Achieved \(Day.long(Day.key(date)))").font(.ui(11)).foregroundStyle(Theme.text3)
                            }
                            Text(rank.name)
                                .font(.system(size: isCurrent ? 30 : 22, weight: .semibold))
                                .foregroundStyle(reached ? .white : Theme.text2)
                                .glow(isCurrent ? rank.tier.light : .clear, radius: 10)
                            Text(reached ? rank.levelRange : "UNLOCKS AT LVL \(rank.minLevel)")
                                .font(.mono(12))
                                .foregroundStyle(isCurrent ? rank.tier.light : Theme.text3)
                        }
                        Spacer()
                    }
                    .id(i)
                    if i < Ranks.all.count - 1 {
                        VStack(spacing: 6) {
                            ForEach(0..<3, id: \.self) { _ in
                                Hexagon()
                                    .stroke(Color.white.opacity(i < currentIndex ? 0.7 : 0.2), lineWidth: 1.5)
                                    .frame(width: 10, height: 10)
                            }
                        }
                        .frame(width: 110)
                        .padding(.vertical, 8)
                    }
                }
            }
            .onAppear {
                proxy.scrollTo(currentIndex, anchor: .center)
            }
        }
        .transparentNavBar()
    }
}

// MARK: - Achievements

struct AchievementsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let snap = model.snap
        ScreenScroll(spacing: 14) {
            ScreenTitle(text: "Achievements.")
            ForEach(Achievements.all) { def in
                let tier = model.achievementTier(def)
                let value = def.metric(snap)
                let nextTarget = tier < def.thresholds.count ? def.thresholds[tier] : nil
                HStack(spacing: 16) {
                    AchievementBadge(symbol: def.symbol, stat: def.stat, tier: tier, size: 60)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(tier > 0 ? "\(def.name) \(roman(tier))" : def.name)
                                .font(.ui(17, .semibold))
                                .foregroundStyle(tier > 0 ? .white : Theme.text2)
                            Spacer()
                            HStack(spacing: 3) {
                                ForEach(1...3, id: \.self) { t in
                                    Image(systemName: t <= tier ? "star.fill" : "star")
                                        .font(.system(size: 10))
                                        .foregroundStyle(t <= tier ? def.stat.color : Theme.text3)
                                }
                            }
                        }
                        if let nextTarget {
                            Text(def.description(tier: tier + 1)).font(.ui(13)).foregroundStyle(Theme.text2)
                            GlowBar(progress: Double(value) / Double(nextTarget), color: def.stat.color, height: 6)
                            MonoLabel("\(min(value, nextTarget)) / \(nextTarget)", size: 10)
                        } else {
                            Text("Maxed out. Legendary.").font(.ui(13)).foregroundStyle(def.stat.color)
                        }
                        if tier > 0, let date = model.unlockDate(def.key, tier: tier) {
                            MonoLabel("Tier \(roman(tier)) · \(Day.long(Day.key(date)))", size: 9)
                        }
                    }
                }
                .padding(14)
                .glassCard(radius: 18)
            }
        }
        .transparentNavBar()
    }
}

// MARK: - Evolution

struct EvolutionView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let snap = model.snap
        let theme = model.theme
        ScreenScroll(spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                ScreenTitle(text: "Evolution.")
                Text("Your avatar evolves as you level up. Ten forms. Only the consistent see the last one.")
                    .font(.ui(15))
                    .foregroundStyle(Theme.text2)
            }

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(EvolutionTheme.allCases) { t in
                        PillTab(title: t.name, selected: t == theme, color: t.color) {
                            model.updateProfile { $0.theme = t }
                            Feedback.tap()
                        }
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 2)
            }
            .scrollIndicators(.hidden)

            ForEach(Array(theme.forms.enumerated()), id: \.offset) { i, form in
                let unlocked = i <= snap.stage
                let isCurrent = i == snap.stage
                HStack(spacing: 16) {
                    SigilView(stage: i, theme: theme, size: isCurrent ? 110 : 76, animated: isCurrent)
                        .saturation(unlocked ? 1 : 0)
                        .opacity(unlocked ? 1 : 0.3)
                    VStack(alignment: .leading, spacing: 4) {
                        MonoLabel("Form \(i + 1) · LVL \(Evolution.levels[i])", color: unlocked ? theme.color : Theme.text3, size: 10)
                        Text(unlocked ? form : "???")
                            .font(.serif(isCurrent ? 34 : 26))
                            .foregroundStyle(unlocked ? .white : Theme.text3)
                        if isCurrent {
                            MonoLabel("Current form", color: theme.color, size: 10)
                        }
                    }
                    Spacer()
                }
                .padding(12)
                .neonCard(theme.color, active: isCurrent, radius: 20, glow: isCurrent)
            }
        }
        .transparentNavBar()
    }
}

// MARK: - Progress card

struct ProgressCardSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var rendered: Image? = nil

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Text("Progress card").font(.serif(30)).foregroundStyle(.white)
                Spacer()
                CloseButton { dismiss() }
            }
            ScrollView {
                ProgressCard(model: model)
                    .frame(width: 340, height: 600)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            if let rendered {
                ShareLink(item: rendered, preview: SharePreview("My DAM progress", image: rendered)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(NeonButtonStyle(color: model.theme.color, filled: true))
            }
        }
        .padding(22)
        .background(AppBackground())
        .sheetSize(width: 440, height: 780)
        .task { render() }
    }

    @MainActor
    private func render() {
        let renderer = ImageRenderer(content:
            ProgressCard(model: model, animated: false)
                .frame(width: 340, height: 600)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .environment(\.colorScheme, .dark)
        )
        renderer.scale = 3
        if let cg = renderer.cgImage {
            rendered = Image(decorative: cg, scale: 3)
        }
    }
}

struct ProgressCard: View {
    let model: AppModel
    var animated = true

    var body: some View {
        let snap = model.snap
        let theme = model.theme
        ZStack {
            Theme.bg
            RadialGradient(colors: [theme.color.opacity(0.3), .clear], center: .top, startRadius: 0, endRadius: 420)
            Image("Grain").resizable(resizingMode: .tile).opacity(0.3).blendMode(.plusLighter)
            VStack(spacing: 10) {
                HStack {
                    Text("DAM.").font(.serif(26)).foregroundStyle(.white)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill").foregroundStyle(Theme.flame)
                        Text("\(snap.streak)").font(.mono(15, .bold)).foregroundStyle(.white)
                    }
                }
                SigilView(stage: snap.stage, theme: theme, size: 150, animated: animated)
                Text(model.profile.name.isEmpty ? "Player" : model.profile.name)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
                Text(model.formName).font(.serif(20)).foregroundStyle(Theme.text2)
                HStack(spacing: 16) {
                    VStack(spacing: 2) {
                        Text("\(snap.level.level)").font(.system(size: 30, weight: .bold)).foregroundStyle(.white)
                        MonoLabel("Level", size: 9)
                    }
                    RankBadge(rank: snap.rank, size: 46)
                    VStack(spacing: 2) {
                        Text("\(snap.ovr)").font(.system(size: 30, weight: .bold)).foregroundStyle(.white)
                        MonoLabel("OVR", size: 9)
                    }
                }
                MonoLabel(snap.rank.code, color: snap.rank.tier.light, size: 12)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(Stat.radarOrder) { stat in
                        VStack(spacing: 2) {
                            Text("\(snap.rating(stat))").font(.system(size: 20, weight: .semibold)).foregroundStyle(.white)
                            Text(stat.name).font(.ui(10)).foregroundStyle(stat.color)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(stat.color.opacity(0.08)))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(stat.color.opacity(0.5), lineWidth: 1))
                    }
                }
                Spacer(minLength: 0)
                MonoLabel("\(snap.totalXP.grouped) XP · best streak \(snap.bestStreak)", color: Theme.text3, size: 9)
            }
            .padding(22)
        }
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(theme.color.opacity(0.6), lineWidth: 1.5))
    }
}
