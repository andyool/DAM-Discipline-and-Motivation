import SwiftUI

struct RadarShape: Shape {
    var values: [Double] // 0...1 in Stat.radarOrder
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        var p = Path()
        for i in 0..<values.count {
            let a = Double(i) * .pi / 3 - .pi / 2
            let v = max(values[i], 0.04) * progress
            let pt = CGPoint(x: c.x + r * v * cos(a), y: c.y + r * v * sin(a))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

struct SpokesShape: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        var p = Path()
        for i in 0..<6 {
            let a = Double(i) * .pi / 3 - .pi / 2
            p.move(to: c)
            p.addLine(to: CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a)))
        }
        return p
    }
}

/// The hexagonal OVR radar from the Progress screen.
struct RadarChart: View {
    let ratings: [Stat: Int]
    let ovr: Int
    var size: CGFloat = 260
    var showLabels = true

    @State private var progress: Double = 0

    private var values: [Double] { Stat.radarOrder.map { Double(ratings[$0] ?? 0) / 99 } }

    var body: some View {
        ZStack {
            ForEach([1.0, 0.66, 0.33], id: \.self) { f in
                Hexagon()
                    .stroke(Color.white.opacity(f == 1 ? 0.16 : 0.08), lineWidth: 1)
                    .frame(width: size * f, height: size * f)
            }
            SpokesShape()
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
                .frame(width: size, height: size)
            RadarShape(values: values, progress: progress)
                .fill(LinearGradient(colors: [Color.white.opacity(0.32), Color.white.opacity(0.12)], startPoint: .top, endPoint: .bottom))
                .frame(width: size, height: size)
            RadarShape(values: values, progress: progress)
                .stroke(Color.white, style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
                .frame(width: size, height: size)
                .shadow(color: .white.opacity(0.8), radius: 8)
            VStack(spacing: 0) {
                Text("\(ovr)")
                    .font(.system(size: size * 0.24, weight: .semibold))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .shadow(color: .white.opacity(0.6), radius: 10)
                MonoLabel("OVR rating", color: Theme.text2, size: max(size * 0.042, 9))
            }
            if showLabels {
                ForEach(Array(Stat.radarOrder.enumerated()), id: \.offset) { i, stat in
                    Text(stat.name)
                        .font(.ui(max(size * 0.058, 11), .medium))
                        .foregroundStyle(stat.color)
                        .shadow(color: stat.color.opacity(0.6), radius: 6)
                        .fixedSize()
                        .offset(labelOffset(i))
                }
            }
        }
        .frame(width: size * (showLabels ? 1.45 : 1.05), height: size * (showLabels ? 1.22 : 1.05))
        .onAppear {
            withAnimation(.spring(duration: 1.3, bounce: 0.3).delay(0.1)) { progress = 1 }
        }
    }

    private func labelOffset(_ i: Int) -> CGSize {
        let v = Hexagon.vertex(i, radius: size / 2 + 16)
        // Push side labels outward horizontally so they clear the hexagon.
        let dx = abs(v.width) > 1 ? v.width + (v.width > 0 ? size * 0.12 : -size * 0.12) : v.width
        return CGSize(width: dx, height: v.height)
    }
}
