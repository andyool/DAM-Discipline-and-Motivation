import SwiftUI

// MARK: - Shapes

/// Pointy-top hexagon, the signature shape of the app.
struct Hexagon: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        var p = Path()
        for i in 0..<6 {
            let a = Double(i) * .pi / 3 - .pi / 2
            let pt = CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }

    /// Offset of vertex `i` from the centre for a hexagon of radius `r`.
    static func vertex(_ i: Int, radius r: CGFloat) -> CGSize {
        let a = Double(i) * .pi / 3 - .pi / 2
        return CGSize(width: r * cos(a), height: r * sin(a))
    }
}

// MARK: - Hex icon

struct HexIcon: View {
    let color: Color
    var size: CGFloat = 30
    var filled = false
    var symbol: String? = nil
    var lineWidth: CGFloat = 2

    var body: some View {
        ZStack {
            Hexagon().fill(color.opacity(filled ? 0.9 : 0.14))
            Hexagon().stroke(color, lineWidth: lineWidth)
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.36, weight: .bold))
                    .foregroundStyle(filled ? Color.black.opacity(0.8) : color)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: color.opacity(filled ? 0.9 : 0.6), radius: filled ? 9 : 5)
    }
}

// MARK: - Background

struct AppBackground: View {
    var tint: Color = Theme.ambient

    var body: some View {
        ZStack {
            Theme.bg
            RadialGradient(colors: [tint.opacity(0.22), .clear], center: .top, startRadius: 0, endRadius: 560)
            RadialGradient(colors: [tint.opacity(0.08), .clear], center: .bottom, startRadius: 0, endRadius: 420)
            Image("Grain")
                .resizable(resizingMode: .tile)
                .opacity(0.32)
                .blendMode(.plusLighter)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Text

struct ScreenTitle: View {
    let text: String
    var size: CGFloat = 46

    var body: some View {
        Text(text)
            .font(.serif(size))
            .foregroundStyle(Theme.text)
            .shadow(color: .white.opacity(0.35), radius: 10)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }
}

struct MonoLabel: View {
    let text: String
    var color: Color = Theme.text3
    var size: CGFloat = 11

    init(_ text: String, color: Color = Theme.text3, size: CGFloat = 11) {
        self.text = text
        self.color = color
        self.size = size
    }

    var body: some View {
        Text(text.uppercased())
            .font(.mono(size))
            .tracking(1.4)
            .foregroundStyle(color)
    }
}

struct SectionHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.ui(17, .semibold))
                .foregroundStyle(Theme.text)
            Spacer()
            trailing()
        }
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(_ title: String) {
        self.title = title
        self.trailing = { EmptyView() }
    }
}

extension View {
    func glow(_ color: Color = .white, radius: CGFloat = 8, opacity: Double = 0.6) -> some View {
        shadow(color: color.opacity(opacity), radius: radius)
    }
}

// MARK: - Cards

struct NeonCardModifier: ViewModifier {
    var color: Color
    var active: Bool
    var radius: CGFloat
    var glow: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return content
            .background(
                shape.fill(LinearGradient(colors: [color.opacity(active ? 0.42 : 0.07), color.opacity(active ? 0.16 : 0.02)],
                                          startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .background(shape.fill(Theme.card))
            .overlay(shape.strokeBorder(color.opacity(active ? 0.95 : 0.55), lineWidth: active ? 1.6 : 1.2))
            .shadow(color: color.opacity(glow ? (active ? 0.55 : 0.26) : 0), radius: active ? 14 : 9)
    }
}

struct GlassCardModifier: ViewModifier {
    var radius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return content
            .background(shape.fill(Theme.card.opacity(0.92)))
            .overlay(shape.strokeBorder(Theme.stroke, lineWidth: 1))
    }
}

extension View {
    func neonCard(_ color: Color, active: Bool = false, radius: CGFloat = 20, glow: Bool = true) -> some View {
        modifier(NeonCardModifier(color: color, active: active, radius: radius, glow: glow))
    }

    func glassCard(radius: CGFloat = 20) -> some View {
        modifier(GlassCardModifier(radius: radius))
    }
}

// MARK: - XP bar

struct GlowBar: View {
    let progress: Double
    var color: Color = Theme.ambient
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.06))
                Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                Capsule()
                    .fill(LinearGradient(colors: [color.opacity(0.65), color], startPoint: .leading, endPoint: .trailing))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
                    .frame(width: max(height, geo.size.width * min(max(progress, 0), 1)))
                    .shadow(color: color.opacity(0.9), radius: 8)
                    .opacity(progress > 0 ? 1 : 0)
            }
        }
        .frame(height: height)
        .animation(.spring(duration: 0.8, bounce: 0.25), value: progress)
    }
}

// MARK: - Buttons

struct NeonButtonStyle: ButtonStyle {
    var color: Color = .white
    var filled = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.mono(13, .semibold))
            .tracking(1.6)
            .textCase(.uppercase)
            .foregroundStyle(filled ? Color.black : color)
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(filled ? color : color.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(color.opacity(filled ? 0 : 0.85), lineWidth: 1.4)
            )
            .shadow(color: color.opacity(configuration.isPressed ? 0.9 : 0.45), radius: configuration.isPressed ? 16 : 10)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.22, bounce: 0.3), value: configuration.isPressed)
    }
}

struct PillTab: View {
    let title: String
    let selected: Bool
    var color: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.ui(15, selected ? .medium : .regular))
                .foregroundStyle(selected ? Theme.text : Theme.text2)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(selected ? color.opacity(0.12) : .clear))
                .overlay(Capsule().strokeBorder(selected ? color.opacity(0.9) : .clear, lineWidth: 1.4))
                .shadow(color: selected ? color.opacity(0.5) : .clear, radius: 8)
        }
        .buttonStyle(.plain)
    }
}

struct StatChip: View {
    let stat: Stat
    var selected: Bool = true
    var compact = false

    var body: some View {
        HStack(spacing: 6) {
            HexIcon(color: stat.color, size: compact ? 14 : 18, filled: selected, lineWidth: 1.5)
            Text(stat.name)
                .font(.ui(compact ? 12 : 14, .medium))
                .foregroundStyle(selected ? stat.color : Theme.text3)
        }
        .padding(.horizontal, compact ? 10 : 12)
        .padding(.vertical, compact ? 6 : 8)
        .background(Capsule().fill(stat.color.opacity(selected ? 0.12 : 0.03)))
        .overlay(Capsule().strokeBorder(stat.color.opacity(selected ? 0.8 : 0.2), lineWidth: 1))
    }
}

/// Small stat tile used in grids (value + caption).
struct ValueTile: View {
    let value: String
    let caption: String
    var color: Color = .white
    var symbol: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if let symbol {
                    Image(systemName: symbol).font(.system(size: 12, weight: .bold)).foregroundStyle(color)
                }
                MonoLabel(caption, color: Theme.text3, size: 10)
            }
            Text(value)
                .font(.ui(26, .semibold))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassCard(radius: 16)
    }
}

// MARK: - Layout helpers

struct ScreenScroll<Content: View>: View {
    var spacing: CGFloat = 22
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: spacing) {
                content()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 40)
            .frame(maxWidth: Theme.maxContentWidth)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(AppBackground())
    }
}

struct CloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.text2)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.cancelAction)
    }
}

extension View {
    @ViewBuilder
    func hiddenNavBar() -> some View {
        #if os(iOS)
        self.toolbar(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }

    @ViewBuilder
    func transparentNavBar() -> some View {
        #if os(iOS)
        self.toolbarBackground(.hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    @ViewBuilder
    func numberPad() -> some View {
        #if os(iOS)
        self.keyboardType(.numberPad)
        #else
        self
        #endif
    }

    @ViewBuilder
    func decimalPad() -> some View {
        #if os(iOS)
        self.keyboardType(.decimalPad)
        #else
        self
        #endif
    }

    /// macOS sheets size to content; give them a sensible minimum.
    @ViewBuilder
    func sheetSize(width: CGFloat = 520, height: CGFloat = 640) -> some View {
        #if os(macOS)
        self.frame(minWidth: width, idealWidth: width, minHeight: height, idealHeight: height)
        #else
        self
        #endif
    }

    @ViewBuilder
    func coverSheet<Content: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        #if os(iOS)
        self.fullScreenCover(isPresented: isPresented, content: content)
        #else
        self.sheet(isPresented: isPresented, content: content)
        #endif
    }
}

extension Int {
    /// 12,345
    var grouped: String {
        let s = String(abs(self))
        var out = ""
        for (i, ch) in s.reversed().enumerated() {
            if i > 0 && i % 3 == 0 { out.append(",") }
            out.append(ch)
        }
        return (self < 0 ? "-" : "") + String(out.reversed())
    }
}

extension Double {
    /// Trims a trailing ".0".
    var clean: String {
        let rounded = (self * 10).rounded() / 10
        return rounded == rounded.rounded() ? String(Int(rounded)) : String(rounded)
    }
}
