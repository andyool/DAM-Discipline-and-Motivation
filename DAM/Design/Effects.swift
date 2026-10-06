import SwiftUI

/// A burst of little hexagons. Change `trigger` to fire it.
struct ParticleBurst: View {
    let trigger: Int
    var colors: [Color]
    var count = 22
    var spread: CGFloat = 120
    var duration: Double = 0.95

    @State private var start: Date? = nil

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: start == nil)) { context in
            Canvas { gc, size in
                guard let start else { return }
                let t = context.date.timeIntervalSince(start)
                guard t >= 0 && t <= duration else { return }
                let progress = t / duration
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                var rng = SeededRandom(seed: UInt64(truncatingIfNeeded: trigger &* 7919 &+ 17))
                for i in 0..<count {
                    let angle = Double.random(in: 0..<(2 * .pi), using: &rng)
                    let speed = Double.random(in: 0.45...1.0, using: &rng)
                    let s = CGFloat.random(in: 4...9, using: &rng)
                    let ease = 1 - pow(1 - progress, 3)
                    let dist = spread * speed * ease
                    let p = CGPoint(x: center.x + cos(angle) * dist, y: center.y + sin(angle) * dist + 40 * progress * progress)
                    let rect = CGRect(x: p.x - s / 2, y: p.y - s / 2, width: s, height: s)
                    let color = colors[i % max(colors.count, 1)]
                    gc.opacity = 1 - progress
                    gc.fill(Hexagon().path(in: rect), with: .color(color))
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in
            let now = Date()
            start = now
            Task {
                try? await Task.sleep(nanoseconds: UInt64((duration + 0.1) * 1_000_000_000))
                if start == now { start = nil }
            }
        }
    }
}

/// "+20 XP" that floats up and fades out once.
struct FloatingText: View {
    let text: String
    let color: Color

    @State private var go = false

    var body: some View {
        Text(text)
            .font(.mono(14, .bold))
            .foregroundStyle(color)
            .shadow(color: color, radius: 8)
            .offset(y: go ? -52 : 0)
            .opacity(go ? 0 : 1)
            .scaleEffect(go ? 1.25 : 0.8)
            .onAppear {
                withAnimation(.easeOut(duration: 1.1)) { go = true }
            }
            .allowsHitTesting(false)
    }
}

/// A diagonal light sweep across the content, repeating.
struct Shine: ViewModifier {
    var active = true
    var period: Double = 2.6

    func body(content: Content) -> some View {
        content.overlay {
            if active {
                TimelineView(.animation) { context in
                    let t = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
                    GeometryReader { geo in
                        LinearGradient(colors: [.clear, .white.opacity(0.55), .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: geo.size.width * 0.35)
                            .rotationEffect(.degrees(20))
                            .offset(x: -geo.size.width * 0.5 + geo.size.width * 2 * t)
                    }
                }
                .mask(content)
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
            }
        }
    }
}

extension View {
    func shine(_ active: Bool = true) -> some View { modifier(Shine(active: active)) }
}

/// Slowly rotating light rays behind celebrations.
struct LightRays: View {
    var color: Color
    var count = 16

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            RaysShape(count: count, inner: 0.02, outer: 0.75)
                .fill(RadialGradient(colors: [color.opacity(0.55), color.opacity(0)], center: .center, startRadius: 0, endRadius: 380))
                .rotationEffect(.radians(t * 0.12))
                .blur(radius: 3)
        }
        .allowsHitTesting(false)
    }
}

/// Falling hexagon confetti for the biggest moments.
struct HexConfetti: View {
    var colors: [Color] = Stat.radarOrder.map(\.color)
    var count = 60

    @State private var start = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { context in
            Canvas { gc, size in
                let t = context.date.timeIntervalSince(start)
                var rng = SeededRandom(seed: 42)
                for i in 0..<count {
                    let x0 = Double.random(in: 0...1, using: &rng) * size.width
                    let delay = Double.random(in: 0...0.8, using: &rng)
                    let speed = Double.random(in: 160...320, using: &rng)
                    let sway = Double.random(in: 10...40, using: &rng)
                    let s = CGFloat.random(in: 6...12, using: &rng)
                    let lt = t - delay
                    guard lt > 0 else { continue }
                    let y = -20 + lt * speed
                    guard y < size.height + 20 else { continue }
                    let x = x0 + sin(lt * 3 + Double(i)) * sway
                    var inner = gc
                    inner.translateBy(x: x, y: y)
                    inner.rotate(by: .radians(lt * 2 + Double(i)))
                    inner.opacity = max(0, 1 - lt / 3.2)
                    inner.fill(Hexagon().path(in: CGRect(x: -s / 2, y: -s / 2, width: s, height: s)),
                               with: .color(colors[i % colors.count]))
                }
            }
        }
        .allowsHitTesting(false)
    }
}
