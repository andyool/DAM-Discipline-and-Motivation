import SwiftUI
#if os(iOS)
import UIKit
#endif

struct FocusView: View {
    @Environment(AppModel.self) private var model
    @State private var minutes: Int = 25
    @State private var burst = 0
    @State private var justFinished = false

    private let presets = [15, 25, 45, 60, 90]

    var body: some View {
        @Bindable var focus = model.focus
        let color = focus.stat.color
        ScreenScroll(spacing: 24) {
            ToolHeader(title: "Lock In.", subtitle: "Deep work. Phone down. 1 XP per minute (5+ min sessions).", color: color)

            TimelineView(.animation(minimumInterval: 0.25, paused: focus.phase != .running)) { context in
                FocusRing(progress: focus.progress(at: context.date), remaining: focus.remaining(at: context.date),
                          color: color, phase: focus.phase, justFinished: justFinished)
            }
            .frame(maxWidth: .infinity)
            .overlay { ParticleBurst(trigger: burst, colors: [color, .white], count: 36, spread: 200) }

            if focus.phase == .idle {
                VStack(alignment: .leading, spacing: 10) {
                    MonoLabel("Duration")
                    HStack(spacing: 8) {
                        ForEach(presets, id: \.self) { m in
                            PillTab(title: "\(m)m", selected: minutes == m, color: color) {
                                minutes = m
                                focus.setDuration(minutes: m)
                                Feedback.tap()
                            }
                        }
                    }
                    Stepper("Custom: \(minutes) min", value: $minutes, in: 5...240, step: 5)
                        .font(.ui(14))
                        .foregroundStyle(Theme.text2)
                        .onChange(of: minutes) { _, m in focus.setDuration(minutes: m) }
                }

                VStack(alignment: .leading, spacing: 10) {
                    MonoLabel("Counts toward")
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach([Stat.ambition, .intellect, .discipline, .mental, .physical, .social]) { stat in
                                Button {
                                    focus.stat = stat
                                    Feedback.tap()
                                } label: {
                                    StatChip(stat: stat, selected: focus.stat == stat, compact: true)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }

                TextField("", text: $focus.label, prompt: Text("What are you locking in on?").foregroundStyle(Theme.text3))
                    .textFieldStyle(.plain)
                    .font(.ui(16))
                    .padding(14)
                    .glassCard(radius: 14)
            }

            controls(focus: focus, color: color)

            HStack(spacing: 10) {
                ValueTile(value: "\(model.focusMinutesToday)", caption: "Minutes today", color: color, symbol: "timer")
                ValueTile(value: (Double(model.snap.counters.focusMinutes) / 60).clean + "h", caption: "All time", color: color, symbol: "hourglass")
            }
        }
        .transparentNavBar()
        .onAppear {
            if focus.phase == .idle {
                minutes = Int(focus.duration / 60)
                if focus.label.isEmpty { focus.stat = model.settings.focusStat }
            }
        }
        .onChange(of: focus.completedCount) { _, _ in
            burst += 1
            justFinished = true
            setIdleTimer(false)
            Task {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                justFinished = false
            }
        }
    }

    @ViewBuilder
    private func controls(focus: FocusController, color: Color) -> some View {
        switch focus.phase {
        case .idle:
            Button("Start") {
                justFinished = false
                focus.start()
                model.updateSettings { $0.focusStat = focus.stat; $0.focusMinutes = minutes }
                if let end = focus.endDate { Reminders.scheduleFocusEnd(at: end, label: focus.label) }
                setIdleTimer(true)
                Feedback.tap()
            }
            .buttonStyle(NeonButtonStyle(color: color, filled: true))
        case .running:
            HStack(spacing: 12) {
                Button("Pause") {
                    focus.pause()
                    Reminders.cancelFocusEnd()
                    setIdleTimer(false)
                }
                .buttonStyle(NeonButtonStyle(color: color))
                Button("End") { end(focus) }
                    .buttonStyle(NeonButtonStyle(color: Theme.text2))
            }
        case .paused:
            HStack(spacing: 12) {
                Button("Resume") {
                    focus.resume()
                    if let end = focus.endDate { Reminders.scheduleFocusEnd(at: end, label: focus.label) }
                    setIdleTimer(true)
                }
                .buttonStyle(NeonButtonStyle(color: color, filled: true))
                Button("End") { end(focus) }
                    .buttonStyle(NeonButtonStyle(color: Theme.text2))
            }
        }
    }

    private func end(_ focus: FocusController) {
        let done = focus.stop()
        Reminders.cancelFocusEnd()
        setIdleTimer(false)
        if done >= 1 {
            model.logFocus(minutes: done, stat: focus.stat, label: focus.label)
            Feedback.handle(.xpGain)
            if done >= 5 { burst += 1 }
        }
    }

    private func setIdleTimer(_ disabled: Bool) {
        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = disabled
        #endif
    }
}

private struct FocusRing: View {
    let progress: Double
    let remaining: TimeInterval
    let color: Color
    let phase: FocusController.Phase
    let justFinished: Bool

    var body: some View {
        let total = Int(remaining.rounded(.up))
        let mm = total / 60
        let ss = total % 60
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.06), lineWidth: 14)
            Circle()
                .trim(from: 0, to: max(progress, 0.001))
                .stroke(AngularGradient(colors: [color.opacity(0.4), color, .white], center: .center),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.8), radius: 12)
            TickRing(count: 60, length: 0.04)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                .padding(26)
            VStack(spacing: 6) {
                if justFinished {
                    Text("Done.").font(.serif(54)).foregroundStyle(.white).glow(color, radius: 14)
                    MonoLabel("XP earned", color: color)
                } else {
                    Text("\(Day.pad(mm, 2)):\(Day.pad(ss, 2))")
                        .font(.system(size: 58, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                        .glow(color, radius: phase == .running ? 14 : 4, opacity: 0.6)
                    MonoLabel(phase == .running ? "Locked in" : (phase == .paused ? "Paused" : "Ready"), color: color)
                }
            }
        }
        .frame(width: 270, height: 270)
        .padding(10)
    }
}
