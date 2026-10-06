import SwiftUI

struct BreathPhase: Hashable {
    let label: String
    let seconds: Double
    let scale: Double
}

struct BreathPattern: Identifiable, Hashable {
    let id: String
    let name: String
    let detail: String
    let phases: [BreathPhase]

    var cycle: Double { phases.reduce(0) { $0 + $1.seconds } }

    static let all: [BreathPattern] = [
        BreathPattern(id: "box", name: "Box", detail: "4-4-4-4. Used by Navy SEALs to stay calm under pressure.",
                      phases: [BreathPhase(label: "Inhale", seconds: 4, scale: 1), BreathPhase(label: "Hold", seconds: 4, scale: 1),
                               BreathPhase(label: "Exhale", seconds: 4, scale: 0.5), BreathPhase(label: "Hold", seconds: 4, scale: 0.5)]),
        BreathPattern(id: "478", name: "Relax", detail: "4-7-8. Slows your heart rate. Great before sleep.",
                      phases: [BreathPhase(label: "Inhale", seconds: 4, scale: 1), BreathPhase(label: "Hold", seconds: 7, scale: 1),
                               BreathPhase(label: "Exhale", seconds: 8, scale: 0.5)]),
        BreathPattern(id: "coherent", name: "Calm", detail: "5.5 in, 5.5 out. Coherent breathing to balance your nervous system.",
                      phases: [BreathPhase(label: "Inhale", seconds: 5.5, scale: 1), BreathPhase(label: "Exhale", seconds: 5.5, scale: 0.5)]),
        BreathPattern(id: "power", name: "Power", detail: "Fast, deep breaths to wake up your body before training.",
                      phases: [BreathPhase(label: "Inhale", seconds: 1.6, scale: 1), BreathPhase(label: "Exhale", seconds: 1.4, scale: 0.55)]),
    ]
}

struct BreathState: Equatable {
    var round: Int
    var phaseIndex: Int
    var phaseProgress: Double
    var scale: Double
    var label: String
    var secondsLeft: Int
    var finished: Bool

    var key: Int { round * 100 + phaseIndex }
}

enum BreathEngine {
    static func state(pattern: BreathPattern, rounds: Int, elapsed: Double) -> BreathState {
        let cycle = pattern.cycle
        guard elapsed < cycle * Double(rounds) else {
            return BreathState(round: rounds, phaseIndex: 0, phaseProgress: 1, scale: 0.5, label: "Done", secondsLeft: 0, finished: true)
        }
        let round = Int(elapsed / cycle)
        var t = elapsed - Double(round) * cycle
        var previousScale = pattern.phases.last?.scale ?? 0.5
        for (i, phase) in pattern.phases.enumerated() {
            if t < phase.seconds {
                let p = t / phase.seconds
                let eased = p * p * (3 - 2 * p)
                let scale = previousScale + (phase.scale - previousScale) * eased
                return BreathState(round: round, phaseIndex: i, phaseProgress: p, scale: scale, label: phase.label,
                                   secondsLeft: Int((phase.seconds - t).rounded(.up)), finished: false)
            }
            t -= phase.seconds
            previousScale = phase.scale
        }
        return BreathState(round: round, phaseIndex: 0, phaseProgress: 0, scale: 0.5, label: "", secondsLeft: 0, finished: false)
    }
}

struct BreatheView: View {
    @Environment(AppModel.self) private var model
    @State private var pattern = BreathPattern.all[0]
    @State private var rounds = 4
    @State private var start: Date? = nil
    @State private var completed = false
    @State private var awarded = 0
    @State private var burst = 0

    private let color = Stat.mental.color

    var body: some View {
        ScreenScroll(spacing: 22) {
            ToolHeader(title: "Breathe.", subtitle: "Calm the mind, sharpen the focus. First 3 sessions a day earn Mental XP.", color: color)

            ZStack {
                if let start {
                    TimelineView(.animation) { context in
                        let s = BreathEngine.state(pattern: pattern, rounds: rounds, elapsed: context.date.timeIntervalSince(start))
                        BreathVisual(state: s, color: color, rounds: rounds)
                            .onChange(of: s.key) { _, _ in
                                if !s.finished { Feedback.breath(inhale: s.label == "Inhale") }
                            }
                            .onChange(of: s.finished) { _, finished in
                                if finished { finish() }
                            }
                    }
                } else {
                    BreathVisual(state: BreathState(round: 0, phaseIndex: 0, phaseProgress: 0, scale: 0.6,
                                                    label: completed ? "Done" : "Ready", secondsLeft: 0, finished: completed),
                                 color: color, rounds: rounds)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 320)
            .overlay { ParticleBurst(trigger: burst, colors: [color, .white], count: 30, spread: 180) }

            if completed {
                Text(awarded > 0 ? "Session complete. +\(awarded) Mental XP." : "Session complete. Nice work.")
                    .font(.ui(15, .medium))
                    .foregroundStyle(color)
                    .frame(maxWidth: .infinity)
            }

            if start == nil {
                VStack(spacing: 10) {
                    ForEach(BreathPattern.all) { p in
                        Button {
                            pattern = p
                            completed = false
                            Feedback.tap()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(p.name).font(.ui(16, .semibold)).foregroundStyle(.white)
                                    Text(p.detail).font(.ui(13)).foregroundStyle(Theme.text2)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer()
                                if pattern == p { Image(systemName: "checkmark").foregroundStyle(color) }
                            }
                            .padding(14)
                            .neonCard(color, active: pattern == p, radius: 16, glow: pattern == p)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                Stepper("Rounds: \(rounds) · ~\(Int((pattern.cycle * Double(rounds) / 60).rounded(.up))) min", value: $rounds, in: 2...20)
                    .font(.ui(15))
                    .foregroundStyle(.white)
                Button("Begin") {
                    completed = false
                    start = Date()
                    Feedback.breath(inhale: true)
                }
                .buttonStyle(NeonButtonStyle(color: color, filled: true))
            } else {
                Button("Stop") { start = nil }
                    .buttonStyle(NeonButtonStyle(color: Theme.text2))
            }
        }
        .transparentNavBar()
    }

    private func finish() {
        guard let start else { return }
        let seconds = Int(Date().timeIntervalSince(start))
        self.start = nil
        completed = true
        awarded = model.logBreath(pattern: pattern.name + " breathing", seconds: seconds)
        burst += 1
    }
}

private struct BreathVisual: View {
    let state: BreathState
    let color: Color
    let rounds: Int

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Hexagon()
                    .stroke(color.opacity(0.12 + Double(i) * 0.05), lineWidth: 1)
                    .frame(width: 300 - CGFloat(i) * 40, height: 300 - CGFloat(i) * 40)
            }
            Hexagon()
                .fill(RadialGradient(colors: [color.opacity(0.55), color.opacity(0.08)], center: .center, startRadius: 0, endRadius: 150))
                .overlay(Hexagon().stroke(color, lineWidth: 2.5))
                .frame(width: 280 * state.scale, height: 280 * state.scale)
                .shadow(color: color.opacity(0.8), radius: 10 + 20 * state.scale)
            VStack(spacing: 4) {
                Text(state.label)
                    .font(.serif(44))
                    .foregroundStyle(.white)
                if state.secondsLeft > 0 {
                    Text("\(state.secondsLeft)")
                        .font(.mono(22, .bold))
                        .foregroundStyle(.white.opacity(0.85))
                        .contentTransition(.numericText())
                    MonoLabel("Round \(min(state.round + 1, rounds)) of \(rounds)", color: Theme.text2, size: 10)
                }
            }
        }
    }
}
