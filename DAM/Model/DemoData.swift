import Foundation

/// Sample history for screenshots and trying the app out (launch with `-demoData YES`).
/// Never touches your real save file.
enum DemoData {
    static func make(today: String = Day.today()) -> AppData {
        var d = AppData()
        let days = 38
        let start = Day.add(-(days - 1), to: today)
        var rng = SeededRandom(seed: 7)

        d.profile.name = "Andy"
        d.profile.onboarded = true
        d.profile.startDay = start
        d.profile.createdAt = Day.date(start)
        d.profile.lastProcessedDay = today
        d.profile.theme = .hunter
        d.profile.wakeMinutes = 6 * 60 + 30
        d.profile.baseline = ["physical": 36, "social": 29, "discipline": 29, "mental": 36, "intellect": 43, "ambition": 36]

        let program = Program(number: 1, startDay: start, intensity: .lockedIn, focus: Stat.allCases)
        d.program = program
        d.habits = ProgramBuilder.habits(for: program, wakeMinutes: d.profile.wakeMinutes)

        func entry(_ kind: EntryKind, _ ref: String, _ day: String, _ stat: Stat, _ xp: Int, _ title: String,
                   id: UUID = UUID(), hour: Double = 9, quantity: Double = 0) -> XPEntry {
            XPEntry(id: id, kind: kind, ref: ref, day: day, date: Day.date(day).addingTimeInterval(hour * 3600), stat: stat,
                    xp: xp, title: title, quantity: quantity, updatedAt: Date())
        }

        for k in 0..<days {
            let day = Day.add(k, to: start)
            let isToday = day == today
            let weekday = Day.weekday(day)
            let streakBoost = min(Double(k), 30) / 60
            for (i, h) in d.habits.enumerated() where h.weekdays.contains(weekday) {
                let done: Bool
                if isToday {
                    done = i < 3
                } else {
                    done = Double.random(in: 0..<1, using: &rng) < (k == 9 ? 0.2 : 0.88)
                }
                guard done else { continue }
                let xp = Int(Double(h.difficulty(programDay: k + 1).xp) * (1 + streakBoost))
                d.entries.append(entry(.habit, h.id.uuidString, day, h.stat, xp, h.title(programDay: k + 1),
                                       id: .stable("habit|\(h.id.uuidString)|\(day)"), hour: 6.5 + Double(i) * 1.6))
            }
            if !isToday && k % 2 == 0 {
                let minutes = [25, 45, 60, 90][k % 4]
                d.entries.append(entry(.focus, "focus", day, .ambition, minutes, "Deep work", hour: 14, quantity: Double(minutes)))
            }
            if !isToday && k % 3 == 1 {
                d.entries.append(entry(.breathe, "Box breathing", day, .mental, 10, "Box breathing", hour: 21, quantity: 64))
            }
            if !isToday, let c = Challenges.daily(for: day).first, k % 3 == 0 {
                d.entries.append(entry(.challenge, c.key, day, c.stat, c.xp, c.name, id: .stable("challenge|\(c.key)|\(day)"), hour: 18))
            }
        }

        for k in stride(from: 1, to: days - 1, by: 2) {
            let day = Day.add(k, to: start)
            let prompts = JournalPrompts.prompts(for: .morning, day: day)
            d.journal.append(JournalEntry(kind: .morning, day: day, date: Day.date(day).addingTimeInterval(7 * 3600), mood: 3 + k % 3,
                                          prompts: prompts, answers: ["My health, my family, a fresh start.", "Finish the project draft and train.", "Getting up on time."]))
            d.entries.append(entry(.journal, "morning", day, .ambition, 15, "Morning journal", id: .stable("journal|morning|\(day)"), hour: 7))
        }

        let plan = [("Push", ["Bench Press", "Overhead Press", "Incline Dumbbell Press"]), ("Pull", ["Pull-ups", "Barbell Row", "Barbell Curl"]),
                    ("Legs", ["Squat", "Romanian Deadlift", "Leg Press"])]
        for (n, k) in stride(from: 0, to: days - 1, by: 3).enumerated() {
            let day = Day.add(k, to: start)
            let (name, exercises) = plan[n % 3]
            let bump = Double(n / 3) * 2.5
            let w = WorkoutLog(name: name, day: day, date: Day.date(day).addingTimeInterval(17 * 3600), durationSeconds: 3600,
                               exercises: exercises.enumerated().map { i, ex in
                                   ExerciseLog(name: ex, sets: (0..<3).map { _ in SetLog(reps: 8, weight: 60 - Double(i) * 15 + bump, done: true) })
                               })
            d.workouts.append(w)
            d.entries.append(entry(.workout, w.id.uuidString, day, .physical, 58, name, id: .stable("workout|\(w.id.uuidString)"), hour: 18, quantity: 9))
        }

        d.meals = [Meal(day: today, date: Date(), name: "Oats & whey", calories: 520, protein: 42),
                   Meal(day: today, date: Date(), name: "Chicken rice bowl", calories: 780, protein: 55)]
        d.water = [DayCount(id: today, value: 5)]

        let arc = ArcRun(templateID: "winter", startDay: Day.add(-11, to: today), length: 90, startedAt: Day.date(Day.add(-11, to: today)))
        d.arcs = [arc]
        for k in 0..<12 where k != 4 {
            let day = Day.add(-11 + k, to: today)
            let miles = [2.1, 3.0, 1.5, 4.2, 2.6, 3.1, 2.0, 5.0, 2.4, 3.3, 2.8, 3.6][k]
            d.arcCheckins.append(ArcCheckin(id: "\(arc.id.uuidString)|\(day)", runID: arc.id, day: day, value: miles))
            d.entries.append(entry(.arc, arc.id.uuidString, day, .physical, 18, "Winter Arc", id: .stable("arc|\(arc.id.uuidString)|\(day)"),
                                   hour: 19, quantity: miles))
        }

        if let c = Challenges.daily(for: today).first {
            d.accepts = [ChallengeAccept(id: "\(c.key)|\(today)", key: c.key, day: today)]
        }
        return d
    }
}
