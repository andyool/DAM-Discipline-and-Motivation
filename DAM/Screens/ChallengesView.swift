import SwiftUI

struct ChallengesView: View {
    @Environment(AppModel.self) private var model
    @State private var starting: ArcTemplate? = nil

    var body: some View {
        let today = model.today
        let month = Calendar.current.component(.month, from: Date())
        let activeIDs = Set(model.activeArcs.map(\.templateID))
        let templates = Arcs.all.filter { !activeIDs.contains($0.id) }
            .sorted { ($0.featuredMonths.contains(month) ? 0 : 1) < ($1.featuredMonths.contains(month) ? 0 : 1) }

        ScreenScroll(spacing: 22) {
            ScreenTitle(text: "Challenges.")

            SectionHeader("Your arcs")
            if model.activeArcs.isEmpty {
                Text("No arc running. Pick one below and commit.")
                    .font(.ui(14))
                    .foregroundStyle(Theme.text3)
            }
            ForEach(model.activeArcs) { run in
                ArcCard(run: run)
            }

            SectionHeader("Daily challenges (\(Day.short(today)))")
            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(Challenges.daily(for: today)) { c in
                        ChallengeCard(challenge: c)
                    }
                }
                .scrollTargetLayout()
                .padding(.vertical, 14)
                .padding(.horizontal, 4)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.never)

            SectionHeader("Start an arc")
            ForEach(templates) { t in
                Button {
                    starting = t
                } label: {
                    ArcTemplateRow(template: t, inSeason: t.featuredMonths.contains(month))
                }
                .buttonStyle(PressableStyle())
            }

            if !model.finishedArcs.isEmpty {
                SectionHeader("History")
                ForEach(model.finishedArcs) { run in
                    if let t = Arcs.template(run.templateID) {
                        HStack {
                            Image(systemName: run.conquered ? "checkmark.seal.fill" : (run.abandoned ? "xmark.circle" : "circle.dashed"))
                                .foregroundStyle(run.conquered ? t.stat.color : Theme.text3)
                            Text(t.name).font(.ui(15)).foregroundStyle(.white)
                            Spacer()
                            MonoLabel(run.conquered ? "Conquered" : (run.abandoned ? "Abandoned" : "Finished"),
                                      color: run.conquered ? t.stat.color : Theme.text3, size: 10)
                            MonoLabel(Day.short(run.startDay), size: 10)
                        }
                        .padding(12)
                        .glassCard(radius: 14)
                    }
                }
            }
        }
        .hiddenNavBar()
        .sheet(item: $starting) { t in
            ArcStartSheet(template: t)
        }
    }
}

// MARK: - Arc card

struct ArcCard: View {
    @Environment(AppModel.self) private var model
    let run: ArcRun

    @State private var logging = false
    @State private var burst = 0
    @State private var confirmAbandon = false

    var body: some View {
        if let t = Arcs.template(run.templateID) {
            let p = model.arcProgress(run)
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text(t.name + ".")
                        .font(.serif(34))
                        .foregroundStyle(.white)
                    Spacer()
                    Countdown(end: p.end, color: t.stat.color)
                }
                HStack(alignment: .top) {
                    metric("\(p.dayNumber)/\(run.length)", "Day")
                    Spacer()
                    if let label = t.metric {
                        metric(p.metricTotal.clean, label)
                    } else {
                        metric("\(p.checked)", "Days done")
                    }
                    Spacer()
                    metric("+\(p.xp)", "\(t.stat.name) XP")
                }
                HStack(spacing: 14) {
                    GlowBar(progress: Double(p.checked) / Double(run.length), color: t.stat.color, height: 10)
                    Button {
                        if p.checkedToday {
                            model.undoCheckIn(run)
                        } else if t.metric != nil {
                            logging = true
                        } else {
                            model.checkIn(run, value: 1)
                            burst += 1
                        }
                    } label: {
                        Image(systemName: p.checkedToday ? "checkmark" : "plus")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(p.checkedToday ? .black : t.stat.color)
                            .frame(width: 48, height: 48)
                            .background(Circle().fill(p.checkedToday ? t.stat.color : t.stat.color.opacity(0.1)))
                            .overlay(Circle().strokeBorder(t.stat.color, lineWidth: 1.5))
                            .shadow(color: t.stat.color.opacity(0.7), radius: 10)
                    }
                    .buttonStyle(PressableStyle())
                    .overlay { ParticleBurst(trigger: burst, colors: [t.stat.color, .white], count: 16, spread: 70) }
                }
                Text(t.rule)
                    .font(.ui(13))
                    .foregroundStyle(Theme.text2)
            }
            .padding(18)
            .background(
                Image(systemName: t.symbol)
                    .font(.system(size: 150, weight: .black))
                    .foregroundStyle(t.stat.color.opacity(0.07))
                    .offset(x: 90, y: 10)
                    .allowsHitTesting(false)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .neonCard(t.stat.color, radius: 20)
            .contextMenu {
                if p.checkedToday {
                    Button("Undo today's check-in", systemImage: "arrow.uturn.backward") { model.undoCheckIn(run) }
                }
                Button("Abandon arc", systemImage: "xmark", role: .destructive) { confirmAbandon = true }
            }
            .sheet(isPresented: $logging) {
                ArcLogSheet(template: t) { value in
                    model.checkIn(run, value: value)
                    burst += 1
                }
            }
            .confirmationDialog("Abandon \(t.name)?", isPresented: $confirmAbandon, titleVisibility: .visible) {
                Button("Abandon", role: .destructive) { model.abandonArc(run) }
            } message: {
                Text("Quitters don't get the conquest bonus. Are you sure?")
            }
        }
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 30, weight: .semibold)).foregroundStyle(.white)
            MonoLabel(label, color: Theme.text3, size: 10)
        }
    }
}

struct Countdown: View {
    let end: Date
    let color: Color

    static func format(_ seconds: Int) -> String {
        let d = seconds / 86400
        let h = (seconds % 86400) / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return "\(Day.pad(d, 2))D \(Day.pad(h, 2))H \(Day.pad(m, 2))M \(Day.pad(s, 2))S"
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let left = max(Int(end.timeIntervalSince(context.date)), 0)
            Text(Countdown.format(left))
                .font(.mono(13, .semibold))
                .foregroundStyle(color)
                .glow(color, radius: 6)
                .monospacedDigit()
        }
    }
}

struct ArcLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    let template: ArcTemplate
    let onLog: (Double) -> Void
    @State private var value: Double = 1

    var body: some View {
        VStack(spacing: 22) {
            HStack {
                Spacer()
                CloseButton { dismiss() }
            }
            MonoLabel("Today's check-in", color: template.stat.color, size: 12)
            Text(template.name + ".").font(.serif(40)).foregroundStyle(.white)
            Text(template.rule).font(.ui(14)).foregroundStyle(Theme.text2).multilineTextAlignment(.center)
            VStack(spacing: 6) {
                TextField("0", value: $value, format: .number)
                    .font(.system(size: 54, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .textFieldStyle(.plain)
                    .decimalPad()
                MonoLabel(template.metric ?? "", color: Theme.text3)
            }
            .padding(.vertical, 10)
            HStack(spacing: 10) {
                ForEach([-1.0, 1.0, 5.0], id: \.self) { step in
                    Button(step > 0 ? "+\(step.clean)" : step.clean) { value = max(0, value + step) }
                        .buttonStyle(.bordered)
                }
            }
            Button("I did it today") {
                onLog(value)
                dismiss()
            }
            .buttonStyle(NeonButtonStyle(color: template.stat.color, filled: true))
            Spacer()
        }
        .padding(24)
        .background(AppBackground())
        .presentationDetents([.medium, .large])
        .sheetSize(width: 440, height: 520)
    }
}

// MARK: - Daily challenge card

struct ChallengeCard: View {
    @Environment(AppModel.self) private var model
    let challenge: ChallengeDef

    @State private var burst = 0

    var body: some View {
        let day = model.today
        let accepted = model.isAccepted(challenge.key, day: day)
        let done = model.isChallengeDone(challenge.key, day: day)
        VStack(alignment: .leading, spacing: 14) {
            Text(challenge.name + ".")
                .font(.serif(40))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Text(challenge.detail)
                .font(.ui(15))
                .foregroundStyle(Theme.text2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                HexIcon(color: challenge.stat.color, size: 22, filled: done)
                MonoLabel(challenge.stat.name, color: challenge.stat.color, size: 12)
                Spacer()
                MonoLabel("+\(challenge.xp) XP", color: .white, size: 12)
            }
            Button {
                if !accepted {
                    model.setAccepted(challenge.key, accepted: true)
                    Feedback.tap()
                } else {
                    let completing = !done
                    model.toggleChallenge(challenge.key, day: day)
                    if completing { burst += 1 }
                }
            } label: {
                Text(done ? "Completed" : (accepted ? "Mark complete" : "Accept challenge"))
            }
            .buttonStyle(NeonButtonStyle(color: challenge.stat.color, filled: done))
        }
        .padding(22)
        .frame(width: 290, height: 380, alignment: .topLeading)
        .background(
            Image(systemName: challenge.symbol)
                .font(.system(size: 190, weight: .black))
                .foregroundStyle(challenge.stat.color.opacity(done ? 0.16 : 0.07))
                .offset(x: 70, y: 40)
                .allowsHitTesting(false)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .neonCard(challenge.stat.color, active: done, radius: 24)
        .overlay { ParticleBurst(trigger: burst, colors: [challenge.stat.color, .white], count: 28, spread: 160) }
    }
}

// MARK: - Arc templates

struct ArcTemplateRow: View {
    let template: ArcTemplate
    let inSeason: Bool

    var body: some View {
        HStack(spacing: 14) {
            HexIcon(color: template.stat.color, size: 44, symbol: template.symbol)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(template.name).font(.ui(17, .semibold)).foregroundStyle(.white)
                    if inSeason {
                        Text("IN SEASON")
                            .font(.mono(9, .bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(template.stat.color))
                    }
                }
                Text(template.tagline).font(.ui(13)).foregroundStyle(Theme.text2)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(template.days)").font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                MonoLabel("days", size: 9)
            }
        }
        .padding(14)
        .neonCard(template.stat.color, active: false, radius: 18, glow: inSeason)
    }
}

struct ArcStartSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let template: ArcTemplate

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Spacer()
                    CloseButton { dismiss() }
                }
                HexIcon(color: template.stat.color, size: 80, filled: true, symbol: template.symbol, lineWidth: 3)
                Text(template.name + ".").font(.serif(48)).foregroundStyle(.white)
                Text(template.tagline).font(.ui(18, .medium)).foregroundStyle(template.stat.color)
                VStack(alignment: .leading, spacing: 8) {
                    MonoLabel("The rule", color: Theme.text3)
                    Text(template.rule).font(.ui(16)).foregroundStyle(.white)
                }
                HStack(spacing: 10) {
                    ValueTile(value: "\(template.days)", caption: "Days", color: template.stat.color)
                    ValueTile(value: "+\(template.checkInXP)", caption: "XP / check-in", color: template.stat.color)
                    ValueTile(value: "+\(template.conquestXP)", caption: "Conquest", color: template.stat.color)
                }
                Text("Check in every day you follow the rule. Hit 90% of days by the end and you conquer the arc for a big XP bonus and an achievement.")
                    .font(.ui(13))
                    .foregroundStyle(Theme.text3)
                Button("Commit to \(template.days) days") {
                    model.startArc(template)
                    Feedback.secured()
                    dismiss()
                }
                .buttonStyle(NeonButtonStyle(color: template.stat.color, filled: true))
                .padding(.top, 6)
            }
            .padding(24)
        }
        .background(AppBackground(tint: template.stat.color))
        .sheetSize(width: 520, height: 680)
    }
}
