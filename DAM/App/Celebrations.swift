import SwiftUI

struct CelebrationLayer: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            if let c = model.celebrations.first {
                CelebrationView(celebration: c, theme: model.theme) {
                    if model.celebrations.first?.id == c.id {
                        withAnimation(.easeInOut(duration: 0.3)) { model.dismissCelebration() }
                    }
                }
                .id(c.id)
                .transition(.opacity.combined(with: .scale(scale: 1.04)))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: model.celebrations.first?.id)
    }
}

struct CelebrationView: View {
    let celebration: Celebration
    let theme: EvolutionTheme
    let dismiss: () -> Void

    var body: some View {
        switch celebration {
        case let .levelUp(level, rank, form, stage):
            LevelUpView(level: level, rank: rank, form: form, stage: stage, theme: theme, dismiss: dismiss)
        case let .daySecured(streak, multiplier, perfect):
            SecuredView(streak: streak, multiplier: multiplier, perfect: perfect, dismiss: dismiss)
        case let .programComplete(number, rate, xp):
            MomentView(eyebrow: "60-day program #\(number)", title: "Complete.", detail: "\(rate)% of days secured. You're not the same person who started.",
                       reward: "+\(xp) XP", symbol: "graduationcap.fill", color: Stat.ambition.color, dismiss: dismiss)
        case let .arcConquered(name, xp):
            MomentView(eyebrow: "Arc conquered", title: "\(name).", detail: "You said you'd do it. You did it.",
                       reward: "+\(xp) XP", symbol: "mountain.2.fill", color: Stat.physical.color, dismiss: dismiss)
        case let .personalRecords(names):
            MomentView(eyebrow: "New personal record", title: "PR.", detail: names.joined(separator: " · "),
                       reward: "+\(10 * names.count) XP", symbol: "trophy.fill", color: Stat.mental.color, dismiss: dismiss)
        }
    }
}

// MARK: - Level up

struct LevelUpView: View {
    let level: Int
    let rank: Rank?
    let form: String?
    let stage: Int
    let theme: EvolutionTheme
    let dismiss: () -> Void

    @State private var show = false
    @State private var showExtra = false

    private var color: Color { rank?.tier.light ?? theme.color }

    var body: some View {
        ZStack {
            Color.black.opacity(0.9).ignoresSafeArea()
            LightRays(color: color)
                .frame(width: 900, height: 900)
                .opacity(show ? 1 : 0)
            if rank != nil || form != nil { HexConfetti().ignoresSafeArea() }
            VStack(spacing: 14) {
                MonoLabel(rank != nil ? "Rank up" : "Level up", color: color, size: 15)
                    .opacity(show ? 1 : 0)
                Text("\(level)")
                    .font(.system(size: 128, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: color, radius: 30)
                    .shadow(color: color.opacity(0.6), radius: 60)
                    .scaleEffect(show ? 1 : 2.6)
                    .opacity(show ? 1 : 0)
                if let form {
                    SigilView(stage: stage, theme: theme, size: 170)
                        .scaleEffect(showExtra ? 1 : 0.3)
                        .opacity(showExtra ? 1 : 0)
                    MonoLabel("You evolved into", color: Theme.text2)
                    Text(form)
                        .font(.serif(40))
                        .foregroundStyle(.white)
                        .glow(theme.color, radius: 12)
                }
                if let rank {
                    RankBadge(rank: rank, size: form == nil ? 110 : 80)
                        .shine()
                        .scaleEffect(showExtra ? 1 : 0.2)
                        .rotationEffect(.degrees(showExtra ? 0 : -25))
                        .opacity(showExtra ? 1 : 0)
                        .padding(.top, 8)
                    Text(rank.name)
                        .font(.serif(42))
                        .foregroundStyle(rank.tier.light)
                        .glow(rank.tier.light, radius: 14)
                }
                if rank == nil && form == nil {
                    Text("Keep stacking days.")
                        .font(.serif(28))
                        .foregroundStyle(Theme.text2)
                        .opacity(show ? 1 : 0)
                }
                Button("Continue", action: dismiss)
                    .buttonStyle(NeonButtonStyle(color: color))
                    .frame(maxWidth: 260)
                    .padding(.top, 18)
                    .opacity(show ? 1 : 0)
            }
            .padding(30)
        }
        .contentShape(Rectangle())
        .onAppear {
            Feedback.levelUp(rankUp: rank != nil || form != nil)
            withAnimation(.spring(duration: 0.6, bounce: 0.45)) { show = true }
            withAnimation(.spring(duration: 0.8, bounce: 0.5).delay(0.45)) { showExtra = true }
        }
    }
}

// MARK: - Day secured

struct SecuredView: View {
    let streak: Int
    let multiplier: Double
    let perfect: Bool
    let dismiss: () -> Void

    @State private var show = false
    @State private var burst = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
                .onTapGesture(perform: dismiss)
            VStack(spacing: 14) {
                ZStack {
                    Hexagon()
                        .fill(RadialGradient(colors: [Theme.flame.opacity(0.55), .clear], center: .center, startRadius: 0, endRadius: 80))
                        .frame(width: 150, height: 150)
                    Hexagon()
                        .stroke(Theme.flame, lineWidth: 2.5)
                        .frame(width: 120, height: 120)
                        .glow(Theme.flame, radius: 14, opacity: 0.9)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 54, weight: .bold))
                        .foregroundStyle(LinearGradient(colors: [.yellow, Theme.flame, .red], startPoint: .top, endPoint: .bottom))
                        .glow(Theme.flame, radius: 16, opacity: 1)
                        .scaleEffect(show ? 1 : 0.4)
                    ParticleBurst(trigger: burst, colors: [Theme.flame, .yellow, .white], count: 30, spread: 150)
                        .frame(width: 300, height: 300)
                }
                MonoLabel(perfect ? "Perfect day" : "Day secured", color: Theme.flame, size: 14)
                Text(streak == 1 ? "Streak started." : "\(streak) days straight.")
                    .font(.serif(42))
                    .foregroundStyle(.white)
                    .glow(radius: 10, opacity: 0.4)
                HStack(spacing: 10) {
                    Label(StreakBonus.label(multiplier) + " XP", systemImage: "bolt.fill")
                    if streak > 0 && streak % 7 == 0 {
                        Label("+1 shield", systemImage: "shield.fill")
                    }
                }
                .font(.mono(13, .semibold))
                .foregroundStyle(Theme.text2)
            }
            .scaleEffect(show ? 1 : 0.85)
            .opacity(show ? 1 : 0)
            .allowsHitTesting(false)
        }
        .onAppear {
            Feedback.secured()
            withAnimation(.spring(duration: 0.55, bounce: 0.5)) { show = true }
            burst += 1
            Task {
                try? await Task.sleep(nanoseconds: 2_600_000_000)
                dismiss()
            }
        }
    }
}

// MARK: - Generic big moment

struct MomentView: View {
    let eyebrow: String
    let title: String
    let detail: String
    let reward: String
    let symbol: String
    let color: Color
    let dismiss: () -> Void

    @State private var show = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.9).ignoresSafeArea()
            LightRays(color: color).frame(width: 900, height: 900).opacity(show ? 0.8 : 0)
            HexConfetti().ignoresSafeArea()
            VStack(spacing: 14) {
                HexIcon(color: color, size: 110, filled: true, symbol: symbol, lineWidth: 3)
                    .scaleEffect(show ? 1 : 0.3)
                MonoLabel(eyebrow, color: color, size: 14)
                Text(title)
                    .font(.serif(54))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .glow(color, radius: 14)
                Text(detail)
                    .font(.ui(16))
                    .foregroundStyle(Theme.text2)
                    .multilineTextAlignment(.center)
                Text(reward)
                    .font(.mono(18, .bold))
                    .foregroundStyle(color)
                    .glow(color, radius: 10)
                Button("Continue", action: dismiss)
                    .buttonStyle(NeonButtonStyle(color: color))
                    .frame(maxWidth: 260)
                    .padding(.top, 14)
            }
            .padding(30)
            .opacity(show ? 1 : 0)
        }
        .onAppear {
            Feedback.levelUp(rankUp: true)
            withAnimation(.spring(duration: 0.6, bounce: 0.45)) { show = true }
        }
    }
}

// MARK: - Toasts

struct ToastLayer: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack {
            if let toast = model.toasts.first, model.celebrations.isEmpty {
                ToastView(toast: toast)
                    .id(toast.id)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture { withAnimation { model.dismissToast(toast) } }
                    .task(id: toast.id) {
                        try? await Task.sleep(nanoseconds: 2_900_000_000)
                        withAnimation(.easeInOut(duration: 0.3)) { model.dismissToast(toast) }
                    }
            }
            Spacer()
        }
        .padding(.top, 8)
        .padding(.horizontal, 16)
        .animation(.spring(duration: 0.45, bounce: 0.3), value: model.toasts.first?.id)
    }
}

struct ToastView: View {
    let toast: Toast

    var body: some View {
        HStack(spacing: 14) {
            AchievementBadge(symbol: toast.symbol, stat: toast.stat, tier: toast.tier, size: 46)
            VStack(alignment: .leading, spacing: 3) {
                MonoLabel("Achievement unlocked", color: toast.stat.color, size: 10)
                Text(toast.title)
                    .font(.mono(15, .bold))
                    .foregroundStyle(.white)
                Text(toast.subtitle)
                    .font(.ui(13))
                    .foregroundStyle(Theme.text2)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: 460)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.ultraThinMaterial))
        .neonCard(toast.stat.color, active: false)
        .onAppear { Feedback.achievement() }
    }
}
