import SwiftUI

/// The evolving avatar. Every evolution stage adds a layer: rings, a stat constellation,
/// rotating dials, rays, orbiting sparks and finally a prismatic crown.
struct SigilView: View {
    let stage: Int
    let theme: EvolutionTheme
    var size: CGFloat = 220
    var animated = true

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !animated)) { context in
            SigilFrame(stage: min(max(stage, 0), 9), color: theme.color, emblem: theme.emblem, size: size,
                       time: animated ? context.date.timeIntervalSinceReferenceDate : 0)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Avatar, evolution stage \(stage + 1)")
    }
}

private struct SigilFrame: View {
    let stage: Int
    let color: Color
    let emblem: String
    let size: CGFloat
    let time: Double

    private var pulse: Double { 0.5 + 0.5 * sin(time * 1.7) }

    var body: some View {
        ZStack {
            aura
            if stage >= 5 { rays }
            if stage >= 3 { dashedRing }
            if stage >= 4 { tickRing }
            if stage >= 7 { outerHex }
            if stage >= 2 { constellation }
            core
            if stage >= 6 { sparks }
            if stage >= 9 { prism }
            emblemView
        }
        .frame(width: size, height: size)
    }

    private var aura: some View {
        Circle()
            .fill(RadialGradient(colors: [color.opacity(0.16 + Double(stage) * 0.025 + 0.06 * pulse), .clear],
                                 center: .center, startRadius: 0, endRadius: size * 0.55))
            .frame(width: size * 1.15, height: size * 1.15)
    }

    private var rays: some View {
        RaysShape(count: 12 + (stage - 5) * 4, inner: 0.26, outer: 0.50 + 0.03 * Double(stage - 5))
            .fill(LinearGradient(colors: [color.opacity(0.35), color.opacity(0)], startPoint: .center, endPoint: .bottom))
            .frame(width: size, height: size)
            .rotationEffect(.radians(time * 0.09))
            .blur(radius: 1.5)
            .opacity(0.55 + 0.3 * pulse)
    }

    private var dashedRing: some View {
        Circle()
            .stroke(color.opacity(0.5), style: StrokeStyle(lineWidth: 1.2, dash: [2, 7]))
            .frame(width: size * 0.93, height: size * 0.93)
            .rotationEffect(.radians(time * 0.18))
    }

    private var tickRing: some View {
        TickRing(count: 48, length: 0.05)
            .stroke(color.opacity(0.55), lineWidth: 1.4)
            .frame(width: size * 0.84, height: size * 0.84)
            .rotationEffect(.radians(-time * 0.12))
    }

    private var outerHex: some View {
        ZStack {
            Hexagon().stroke(color.opacity(0.45), lineWidth: 1.2)
            Hexagon().stroke(color.opacity(0.2), lineWidth: 6).blur(radius: 6)
        }
        .frame(width: size * 0.97, height: size * 0.97)
        .rotationEffect(.radians(.pi / 6 + time * 0.05))
    }

    private var constellation: some View {
        let r = size * 0.36
        let spin = stage >= 8 ? time * 0.07 : 0
        return ZStack {
            Hexagon()
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
                .frame(width: r * 2, height: r * 2)
            ForEach(0..<6, id: \.self) { i in
                HexIcon(color: Stat.radarOrder[i].color, size: size * 0.1, filled: stage >= 6, lineWidth: 1.5)
                    .offset(Hexagon.vertex(i, radius: r))
                    .rotationEffect(.radians(-spin))
            }
        }
        .rotationEffect(.radians(spin))
    }

    private var core: some View {
        let s = size * (0.44 + 0.012 * Double(stage))
        return ZStack {
            Hexagon()
                .fill(RadialGradient(colors: [color.opacity(0.6), color.opacity(0.12), Color.black.opacity(0.9)],
                                     center: .center, startRadius: 0, endRadius: s * 0.55))
            Hexagon()
                .stroke(LinearGradient(colors: [.white, color, color.opacity(0.6)], startPoint: .top, endPoint: .bottom),
                        lineWidth: 2 + Double(stage) * 0.25)
                .shadow(color: color, radius: 6 + 8 * pulse)
            if stage >= 1 {
                Hexagon()
                    .stroke(color.opacity(0.75), lineWidth: 1)
                    .frame(width: s * 0.66, height: s * 0.66)
                    .rotationEffect(.degrees(30))
            }
        }
        .frame(width: s, height: s)
    }

    private var sparks: some View {
        let count = stage - 3
        return ZStack {
            ForEach(0..<count, id: \.self) { k in
                let angle = time * (0.6 + 0.12 * Double(k)) + Double(k) * 2 * .pi / Double(count)
                let radius = size * (0.3 + 0.03 * Double(k % 3))
                Circle()
                    .fill(Color.white)
                    .frame(width: 3.5, height: 3.5)
                    .shadow(color: color, radius: 5)
                    .offset(x: cos(angle) * radius, y: sin(angle) * radius)
            }
        }
    }

    private var prism: some View {
        let colors = Stat.radarOrder.map(\.color) + [Stat.radarOrder[0].color]
        return Hexagon()
            .stroke(AngularGradient(colors: colors, center: .center), lineWidth: 3)
            .frame(width: size * 0.62, height: size * 0.62)
            .rotationEffect(.radians(time * 0.35))
            .shadow(color: .white.opacity(0.6), radius: 8)
    }

    private var emblemView: some View {
        Image(systemName: emblem)
            .font(.system(size: size * (0.12 + 0.008 * Double(stage)), weight: .bold))
            .foregroundStyle(.white)
            .shadow(color: color, radius: 6 + 6 * pulse)
            .scaleEffect(1 + 0.03 * pulse)
    }
}

struct RaysShape: Shape {
    var count: Int
    var inner: Double
    var outer: Double

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height)
        var p = Path()
        for i in 0..<max(count, 1) {
            let a = Double(i) / Double(count) * 2 * .pi
            let w = .pi / Double(count) * 0.35
            p.move(to: CGPoint(x: c.x + cos(a - w) * r * inner, y: c.y + sin(a - w) * r * inner))
            p.addLine(to: CGPoint(x: c.x + cos(a) * r * outer, y: c.y + sin(a) * r * outer))
            p.addLine(to: CGPoint(x: c.x + cos(a + w) * r * inner, y: c.y + sin(a + w) * r * inner))
            p.closeSubpath()
        }
        return p
    }
}

struct TickRing: Shape {
    var count: Int
    var length: Double

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        var p = Path()
        for i in 0..<count {
            let a = Double(i) / Double(count) * 2 * .pi
            let l = i % 4 == 0 ? length * 2 : length
            p.move(to: CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r))
            p.addLine(to: CGPoint(x: c.x + cos(a) * r * (1 - l), y: c.y + sin(a) * r * (1 - l)))
        }
        return p
    }
}
