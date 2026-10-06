import SwiftUI

// MARK: - Shapes

struct ShieldShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height, x = rect.minX, y = rect.minY
        var p = Path()
        p.move(to: CGPoint(x: x + w * 0.5, y: y))
        p.addLine(to: CGPoint(x: x + w, y: y + h * 0.16))
        p.addLine(to: CGPoint(x: x + w, y: y + h * 0.52))
        p.addQuadCurve(to: CGPoint(x: x + w * 0.5, y: y + h), control: CGPoint(x: x + w * 0.97, y: y + h * 0.84))
        p.addQuadCurve(to: CGPoint(x: x, y: y + h * 0.52), control: CGPoint(x: x + w * 0.03, y: y + h * 0.84))
        p.addLine(to: CGPoint(x: x, y: y + h * 0.16))
        p.closeSubpath()
        return p
    }
}

struct GemShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.38))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.38))
        p.closeSubpath()
        return p
    }
}

struct GemFacets: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let mid = CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.38)
        p.move(to: CGPoint(x: rect.minX, y: mid.y))
        p.addLine(to: CGPoint(x: rect.maxX, y: mid.y))
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.3, y: mid.y))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.7, y: mid.y))
        p.closeSubpath()
        return p
    }
}

/// Crown spikes above the shield for higher tiers.
struct SpikesShape: Shape {
    var count: Int

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let n = max(count, 1)
        let step = rect.width / CGFloat(n)
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        for i in 0..<n {
            let x0 = rect.minX + CGFloat(i) * step
            let peak = i == n / 2 ? rect.minY : rect.minY + rect.height * 0.35
            p.addLine(to: CGPoint(x: x0 + step / 2, y: peak))
            p.addLine(to: CGPoint(x: x0 + step, y: rect.maxY))
        }
        p.closeSubpath()
        return p
    }
}

/// One wing, drawn for the left side; mirror it for the right.
struct WingShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height, x = rect.minX, y = rect.minY
        p.move(to: CGPoint(x: x + w, y: y + h * 0.25))
        p.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: x + w * 0.4, y: y + h * 0.02))
        p.addQuadCurve(to: CGPoint(x: x + w * 0.35, y: y + h * 0.45), control: CGPoint(x: x + w * 0.05, y: y + h * 0.35))
        p.addQuadCurve(to: CGPoint(x: x + w * 0.1, y: y + h * 0.6), control: CGPoint(x: x + w * 0.2, y: y + h * 0.5))
        p.addQuadCurve(to: CGPoint(x: x + w * 0.5, y: y + h * 0.85), control: CGPoint(x: x + w * 0.25, y: y + h * 0.8))
        p.addQuadCurve(to: CGPoint(x: x + w, y: y + h * 0.75), control: CGPoint(x: x + w * 0.8, y: y + h * 0.9))
        p.closeSubpath()
        return p
    }
}

/// Tall crest used for achievement badges.
struct CrestShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height, x = rect.minX, y = rect.minY
        var p = Path()
        p.move(to: CGPoint(x: x + w * 0.5, y: y))
        p.addLine(to: CGPoint(x: x + w, y: y + h * 0.16))
        p.addLine(to: CGPoint(x: x + w, y: y + h * 0.74))
        p.addLine(to: CGPoint(x: x + w * 0.5, y: y + h))
        p.addLine(to: CGPoint(x: x, y: y + h * 0.74))
        p.addLine(to: CGPoint(x: x, y: y + h * 0.16))
        p.closeSubpath()
        return p
    }
}

// MARK: - Rank badge

struct RankBadge: View {
    let rank: Rank
    var size: CGFloat = 64
    var locked = false
    var glow = true

    private var tier: RankTier { rank.tier }
    private var level: Int { tier.rawValue }

    var body: some View {
        ZStack {
            if level >= RankTier.diamond.rawValue { wings }
            if level >= RankTier.gold.rawValue { spikes }
            shield
            gem
            if rank.division > 0 {
                Text(roman(rank.division))
                    .font(.serif(size * 0.2))
                    .foregroundStyle(tier.light)
                    .shadow(color: .black, radius: 1)
                    .offset(y: size * 0.31)
            }
        }
        .frame(width: size * 1.3, height: size * 1.25)
        .saturation(locked ? 0 : 1)
        .opacity(locked ? 0.32 : 1)
        .overlay(alignment: .bottomLeading) {
            if locked {
                Image(systemName: "lock.fill")
                    .font(.system(size: size * 0.2, weight: .bold))
                    .foregroundStyle(Theme.text2)
                    .offset(x: size * 0.12, y: -size * 0.08)
            }
        }
        .shadow(color: glow && !locked ? tier.light.opacity(0.55) : .clear, radius: size * 0.18)
    }

    private var wings: some View {
        HStack(spacing: size * 0.42) {
            WingShape()
                .fill(LinearGradient(colors: [tier.light, tier.dark], startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.42, height: size * 0.62)
            WingShape()
                .fill(LinearGradient(colors: [tier.light, tier.dark], startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.42, height: size * 0.62)
                .scaleEffect(x: -1, y: 1)
        }
        .offset(y: -size * 0.08)
    }

    private var spikes: some View {
        SpikesShape(count: level >= RankTier.master.rawValue ? 5 : 3)
            .fill(LinearGradient(colors: [tier.light, tier.dark], startPoint: .top, endPoint: .bottom))
            .frame(width: size * 0.62, height: size * 0.26)
            .offset(y: -size * 0.5)
    }

    private var shield: some View {
        ZStack {
            ShieldShape()
                .fill(LinearGradient(colors: [tier.light, tier.dark, tier.dark.opacity(0.9)], startPoint: .top, endPoint: .bottom))
            ShieldShape()
                .stroke(LinearGradient(colors: [.white.opacity(0.9), tier.light, tier.dark], startPoint: .top, endPoint: .bottom),
                        lineWidth: max(size * 0.035, 1))
            ShieldShape()
                .fill(LinearGradient(colors: [Color.black.opacity(0.55), Color.black.opacity(0.25)], startPoint: .top, endPoint: .bottom))
                .padding(size * 0.1)
        }
        .frame(width: size * 0.8, height: size * 0.95)
    }

    private var gem: some View {
        ZStack {
            GemShape()
                .fill(LinearGradient(colors: [.white, tier.light, tier.dark], startPoint: .topLeading, endPoint: .bottomTrailing))
            GemFacets()
                .stroke(Color.white.opacity(0.55), lineWidth: max(size * 0.012, 0.5))
            GemShape()
                .stroke(Color.white.opacity(0.8), lineWidth: max(size * 0.015, 0.5))
        }
        .frame(width: size * 0.36, height: size * 0.42)
        .shadow(color: tier.light, radius: size * 0.08)
        .offset(y: -size * 0.05)
    }
}

// MARK: - Achievement badge

struct AchievementBadge: View {
    let symbol: String
    let stat: Stat
    let tier: Int // 0 = locked
    var size: CGFloat = 72

    private var metal: [Color] {
        switch tier {
        case 3: return [Color(red: 1, green: 0.93, blue: 0.6), Color(red: 0.85, green: 0.6, blue: 0.15)]
        case 2: return [Color(red: 0.95, green: 0.97, blue: 1), Color(red: 0.5, green: 0.55, blue: 0.65)]
        default: return [Color(red: 0.95, green: 0.7, blue: 0.48), Color(red: 0.5, green: 0.28, blue: 0.12)]
        }
    }

    var body: some View {
        ZStack {
            if tier >= 2 {
                SpikesShape(count: tier == 3 ? 5 : 3)
                    .fill(LinearGradient(colors: metal, startPoint: .top, endPoint: .bottom))
                    .frame(width: size * 0.5, height: size * 0.18)
                    .offset(y: -size * 0.5)
            }
            CrestShape()
                .fill(LinearGradient(colors: [stat.color, stat.color.opacity(0.55), Color.black.opacity(0.8)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.72, height: size * 0.92)
            CrestShape()
                .stroke(LinearGradient(colors: metal, startPoint: .top, endPoint: .bottom), lineWidth: size * 0.06)
                .frame(width: size * 0.72, height: size * 0.92)
            CrestShape()
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
                .frame(width: size * 0.56, height: size * 0.74)
            Image(systemName: symbol)
                .font(.system(size: size * 0.28, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: stat.color, radius: 6)
            GemShape()
                .fill(LinearGradient(colors: metal, startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.14, height: size * 0.16)
                .offset(y: size * 0.46)
        }
        .frame(width: size, height: size * 1.12)
        .saturation(tier == 0 ? 0 : 1)
        .opacity(tier == 0 ? 0.28 : 1)
        .shadow(color: tier == 0 ? .clear : stat.color.opacity(0.5), radius: size * 0.14)
    }
}
