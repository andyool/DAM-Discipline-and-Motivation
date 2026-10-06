import SwiftUI

struct CoachView: View {
    @Environment(AppModel.self) private var model
    @State private var session = CoachSession()
    @State private var input = ""
    @FocusState private var inputFocused: Bool

    private let quickPrompts = ["Plan my day", "I don't feel like it today", "How am I doing?", "I missed yesterday", "Roast my stats"]

    var body: some View {
        let color = model.theme.color
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            ScreenTitle(text: "Coach.")
                            HStack(spacing: 6) {
                                Circle().fill(session.usesAI ? Stat.physical.color : Theme.text3).frame(width: 7, height: 7)
                                MonoLabel(session.usesAI ? "On-device AI · private · free" : "Classic coach · works offline", color: Theme.text2, size: 10)
                            }
                        }
                        .padding(.bottom, 8)

                        ForEach(session.messages) { m in
                            MessageBubble(message: m, color: color)
                                .id(m.id)
                        }
                        if session.thinking {
                            TypingIndicator(color: color).id("typing")
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: Theme.maxContentWidth)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: session.messages.count) { _, _ in
                    if let id = session.messages.last?.id {
                        withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo(id, anchor: .bottom) }
                    }
                }
                .onChange(of: session.thinking) { _, thinking in
                    if thinking { withAnimation { proxy.scrollTo("typing", anchor: .bottom) } }
                }
            }

            VStack(spacing: 10) {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(quickPrompts, id: \.self) { p in
                            Button {
                                send(p)
                            } label: {
                                Text(p)
                                    .font(.ui(13))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Capsule().fill(Color.white.opacity(0.07)))
                                    .overlay(Capsule().strokeBorder(color.opacity(0.4)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .scrollIndicators(.hidden)
                HStack(spacing: 10) {
                    TextField("", text: $input, prompt: Text("Talk to your coach…").foregroundStyle(Theme.text3), axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.ui(16))
                        .lineLimit(1...4)
                        .focused($inputFocused)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 20).fill(Color.white.opacity(0.07)))
                        .onSubmit { send(input) }
                    Button {
                        send(input)
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: 42, height: 42)
                            .background(Circle().fill(color))
                            .shadow(color: color.opacity(0.6), radius: 8)
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || session.thinking)
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: Theme.maxContentWidth)
            }
            .padding(.vertical, 12)
            .background(Theme.bg.opacity(0.85))
        }
        .transparentNavBar()
        .onAppear { session.greet(model) }
    }

    private func send(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !session.thinking else { return }
        input = ""
        Feedback.tap()
        Task { await session.send(t, model: model) }
    }
}

private struct MessageBubble: View {
    let message: CoachMessage
    let color: Color

    var body: some View {
        HStack {
            if message.fromUser { Spacer(minLength: 50) }
            Text(message.text)
                .font(.ui(15))
                .foregroundStyle(.white)
                .textSelection(.enabled)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(message.fromUser ? Color.white.opacity(0.1) : color.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(message.fromUser ? Color.white.opacity(0.08) : color.opacity(0.45), lineWidth: 1)
                )
            if !message.fromUser { Spacer(minLength: 50) }
        }
    }
}

private struct TypingIndicator: View {
    let color: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.15, paused: false)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(color)
                        .frame(width: 7, height: 7)
                        .opacity(0.3 + 0.7 * max(0, sin(t * 5 - Double(i) * 0.8)))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 18).fill(color.opacity(0.1)))
        }
    }
}
