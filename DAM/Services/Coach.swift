import Foundation
import Observation
#if canImport(FoundationModels)
import FoundationModels
#endif

struct CoachMessage: Identifiable, Hashable {
    let id = UUID()
    let fromUser: Bool
    let text: String
}

/// Chat with the coach. Uses Apple's on-device model (Apple Intelligence) when available, free and private;
/// otherwise falls back to the built-in rule-based coach.
@MainActor
@Observable
final class CoachSession {
    var messages: [CoachMessage] = []
    var thinking = false
    let usesAI: Bool

    @ObservationIgnored private var llm: Any? = nil

    init() {
        usesAI = CoachAI.isAvailable
    }

    func greet(_ model: AppModel) {
        guard messages.isEmpty else { return }
        messages.append(CoachMessage(fromUser: false, text: CoachBrain.greeting(model)))
    }

    func send(_ text: String, model: AppModel) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        messages.append(CoachMessage(fromUser: true, text: trimmed))
        thinking = true
        defer { thinking = false }

        if let crisis = CoachBrain.crisisReply(trimmed) {
            messages.append(CoachMessage(fromUser: false, text: crisis))
            return
        }
        if usesAI {
            if llm == nil { llm = CoachAI.makeSession() }
            let prompt = "Context about me right now:\n\(CoachBrain.context(model))\n\nMy message: \(trimmed)"
            if let reply = await CoachAI.respond(session: llm, prompt: prompt), !reply.isEmpty {
                messages.append(CoachMessage(fromUser: false, text: reply))
                return
            }
            llm = nil // start fresh next time (e.g. context window exceeded)
        }
        try? await Task.sleep(nanoseconds: 450_000_000)
        messages.append(CoachMessage(fromUser: false, text: CoachBrain.reply(to: trimmed, model: model)))
    }
}

enum CoachAI {
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability { return true }
        }
        #endif
        return false
    }

    static func makeSession() -> Any? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return LanguageModelSession(instructions: """
                You are DAM Coach, a self-discipline coach inside a gamified self-improvement app. \
                Your style: direct, warm, tough-love, like a coach who believes in the user. Short punchy sentences. \
                Keep replies under 90 words unless asked for a plan. Give one concrete next action whenever you can. \
                Use the context the user shares (level, streak, tasks, stats) to personalise advice. \
                Never shame the user. Never give medical diagnoses. If someone seems in danger, urge them to contact local emergency services or a crisis line.
                """)
        }
        #endif
        return nil
    }

    static func respond(session: Any?, prompt: String) async -> String? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *), let s = session as? LanguageModelSession {
            do {
                let response = try await s.respond(to: prompt)
                return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            } catch {
                return nil
            }
        }
        #endif
        return nil
    }
}

/// The classic, offline coach. Reads your stats and answers with tough love.
@MainActor
enum CoachBrain {
    static func context(_ model: AppModel) -> String {
        let s = model.snap
        let tasks = model.tasks(for: model.today)
        let left = tasks.filter { !$0.done }.map(\.title)
        let ratings = Stat.radarOrder.map { "\($0.name) \(s.rating($0))" }.joined(separator: ", ")
        var lines = [
            "Name: \(model.profile.name.isEmpty ? "unknown" : model.profile.name)",
            "Level \(s.level.level), rank \(s.rank.name), form \(model.formName)",
            "Streak: \(s.streak) days (best \(s.bestStreak)), XP multiplier \(StreakBonus.label(s.multiplier))",
            "Today: \(tasks.count - left.count)/\(tasks.count) tasks done",
            "OVR \(s.ovr). Stats: \(ratings). Weakest: \(s.weakestStat.name)",
        ]
        if let day = s.programDay, day <= 60 { lines.append("60-day program: day \(day)") }
        if !left.isEmpty { lines.append("Still to do today: " + left.prefix(6).joined(separator: "; ")) }
        return lines.joined(separator: "\n")
    }

    static func greeting(_ model: AppModel) -> String {
        let name = model.profile.name.isEmpty ? "" : " \(model.profile.name)"
        return "What's up\(name). I'm your coach. Tell me what's in your way today, ask for a plan, or ask how you're doing. I'll keep it real."
    }

    /// Short line for the Home screen.
    static func insight(_ model: AppModel) -> String {
        let s = model.snap
        let tasks = model.tasks(for: model.today)
        let left = tasks.filter { !$0.done }
        let hour = Calendar.current.component(.hour, from: Date())
        if tasks.isEmpty { return "No tasks today. Add one. A day without a target is a day wasted." }
        if left.isEmpty {
            return s.streak > 1
                ? "Day secured. \(s.streak) days straight. Most people quit by now. You didn't."
                : "Day secured. Rest up. Tomorrow we go again."
        }
        if left.count == tasks.count {
            if hour < 12 { return "Clean slate. Knock out \"\(left[0].title)\" first. Momentum does the rest." }
            if hour >= 19 { return "Nothing checked yet and the day is closing. Start with the easiest one. Now." }
            return "Zero for \(tasks.count) so far. One task. Right now. Go."
        }
        if hour >= 19 {
            return s.streak > 0
                ? "\(left.count) left. Your \(s.streak)-day streak is on the line. Finish strong."
                : "\(left.count) left. Secure the day and start a streak tonight."
        }
        let weak = s.weakestStat
        if s.rating(weak) + 8 < s.ovr {
            return "\(weak.name) is your weakest stat (\(s.rating(weak))). \(weak.improveTip)"
        }
        return "\(tasks.count - left.count) down, \(left.count) to go. Keep the momentum."
    }

    static func crisisReply(_ text: String) -> String? {
        let t = text.lowercased()
        let flags = ["kill myself", "suicide", "suicidal", "end my life", "want to die", "self harm", "self-harm", "hurt myself"]
        guard flags.contains(where: { t.contains($0) }) else { return nil }
        return "I'm really glad you told me. This is bigger than discipline, and you don't have to carry it alone. Please reach out right now: call or text 988 (US), or find your local line at findahelpline.com. If you're in immediate danger, call emergency services. Talking to someone you trust today matters more than any task."
    }

    static func reply(to text: String, model: AppModel) -> String {
        let t = text.lowercased()
        let s = model.snap
        let tasks = model.tasks(for: model.today)
        let left = tasks.filter { !$0.done }
        func has(_ words: [String]) -> Bool { words.contains { t.contains($0) } }

        if has(["how am i", "progress", "my stats", "doing", "report"]) {
            let strong = s.strongestStat, weak = s.weakestStat
            return "Level \(s.level.level), \(s.rank.name). OVR \(s.ovr). Strongest: \(strong.name) (\(s.rating(strong))). Weakest: \(weak.name) (\(s.rating(weak))). Streak \(s.streak) days, best \(s.bestStreak). \(s.level.remaining) XP to level \(s.level.level + 1). Verdict: \(s.streak >= 7 ? "you're building something real. Don't get comfortable." : "decent start. Consistency is the whole game. Stack days.")"
        }
        if has(["plan", "what should i do", "what now", "order", "schedule"]) {
            if left.isEmpty { return "Everything's done. Plan tomorrow tonight: write your top 3, lay out your clothes, phone out of the bedroom." }
            let sorted = left.sorted { $0.xp > $1.xp }
            let list = sorted.prefix(5).enumerated().map { "\($0.offset + 1). \($0.element.title)" }.joined(separator: "\n")
            return "Here's the order. Hardest first while your willpower is fresh:\n\(list)\nStart #1 in the next 5 minutes. No negotiating."
        }
        if has(["roast"]) {
            let weak = s.weakestStat
            return "\(weak.name) at \(s.rating(weak))? My guy. That stat is on life support. You've got \(left.count) tasks left and you're in here asking for a roast. Go fix it, then come back and talk."
        }
        if has(["tired", "exhausted", "sleepy", "no energy", "drained"]) {
            return "Tired is real. Quitting isn't the cure. Do the smallest version: 10 minutes instead of 60, 2 pages instead of 20. The rule is never zero. Then get to bed early tonight, because recovery is part of the program."
        }
        if has(["motivat", "don't feel like", "dont feel like", "lazy", "can't be bothered", "cant be bothered", "unmotivated"]) {
            return "Motivation is a feeling. Feelings come and go. Discipline is a decision you make before the feeling shows up. Don't wait to feel ready. Start for 2 minutes and let action create the motivation."
        }
        if has(["missed", "broke", "failed", "fail", "messed up", "relapse", "slipped"]) {
            return "You slipped. Fine. Everybody does. The rule that matters: never miss twice. One bad day is an accident, two is the start of a new habit. Secure today and the slip becomes a footnote."
        }
        if has(["quit", "give up", "pointless", "what's the point", "whats the point"]) {
            return "Remember why you started. The version of you that wanted this hasn't gone anywhere; he's just buried under today's excuses. You don't need to win the month tonight. Just win the next hour."
        }
        if has(["procrastinat", "later", "tomorrow", "putting off", "avoid"]) {
            return "Procrastination is fear in a disguise. Shrink the task until it's stupidly easy: open the doc, put on the shoes, read one page. Set a 5-minute Lock In timer and start before your brain can argue."
        }
        if has(["phone", "scroll", "tiktok", "instagram", "social media", "screen time", "youtube"]) {
            return "Your phone is designed by thousands of engineers to steal your attention. Fight back with friction: grayscale mode, apps off the home screen, phone in another room while you work. Every hour you take back goes to your goals."
        }
        if has(["gym", "workout", "train", "lift", "exercise", "run"]) {
            return "Train today, even if it's ugly. Show up, warm up, do the first set, and decide after. 90% of the battle is walking through the door. Log it in the Lift tracker so you can beat it next time."
        }
        if has(["sad", "depressed", "lonely", "anxious", "anxiety", "stress", "overwhelmed", "down"]) {
            return "That's heavy, and it's okay to feel it. Do one thing for your mind right now: 3 rounds of box breathing in the Breathe tool, then a short walk outside. Text someone you trust. If it keeps weighing on you, talking to a professional is strength, not weakness."
        }
        if has(["sleep", "wake up", "waking", "morning"]) {
            return "Fix the night to fix the morning. Same bedtime every night, screens off 30 minutes before, alarm across the room. When it rings: feet on the floor before your brain wakes up and starts negotiating."
        }
        if has(["diet", "eat", "food", "protein", "calorie", "nutrition"]) {
            return "Keep it simple: protein at every meal, mostly whole foods, water before every meal. Track it in Fuel for a week and you'll see exactly where the leaks are."
        }
        if has(["thank", "thanks", "appreciate"]) {
            return "Don't thank me. Thank yourself by finishing today. Go."
        }
        if has(["hi", "hey", "hello", "yo", "sup"]) {
            return left.isEmpty
                ? "Day's already secured. Respect. Want a plan for tomorrow?"
                : "Yo. \(left.count) tasks waiting. What's stopping you from doing the next one right now?"
        }
        let lines = [
            "Real talk: the answer is usually simpler than you want it to be. Do the next task on your list. Then the next.",
            "You already know what to do. The gap is between knowing and doing. Close it today.",
            "Hard choices, easy life. Easy choices, hard life. Pick your hard.",
            "Nobody is coming to save you. That's the good news: it means you're in control.",
        ]
        return lines[Int(UInt(bitPattern: t.hashValue) % UInt(lines.count))] + (left.isEmpty ? "" : " You've got \(left.count) left today.")
    }
}
