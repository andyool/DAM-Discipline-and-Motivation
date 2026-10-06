import Foundation

enum DayState: Hashable {
    case future, empty, pending, partial, secured, perfect, missed, shielded

    var isWin: Bool { self == .secured || self == .perfect }
}

struct DayRecord: Hashable {
    var scheduled = 0
    var done = 0
    var ratio: Double { scheduled > 0 ? Double(done) / Double(scheduled) : 0 }
}

struct Counters: Hashable {
    var tasksCompleted = 0
    var earlyBird = 0
    var statActivities: [Stat: Int] = [:]
    var focusMinutes = 0
    var focusSessions = 0
    var breathSessions = 0
    var journalEntries = 0
    var workouts = 0
    var challenges = 0
    var arcsConquered = 0
    var nutritionDays = 0
    var programsCompleted = 0
    var perfectWeeks = 0
    var perfectDays = 0
    var securedDays = 0
    var affirmationDays = 0
}

/// Everything the UI shows, derived from the raw records.
struct Snapshot {
    var today: String
    var totalXP = 0
    var xpToday = 0
    var level = Leveling.state(totalXP: 0)
    var rank: Rank = Ranks.all[0]
    var stage = 0
    var streak = 0
    var bestStreak = 0
    var shields = 0
    var multiplier = 1.0
    var todayRecord = DayRecord()
    var todaySecured = false
    var states: [String: DayState] = [:]
    var records: [String: DayRecord] = [:]
    var statXP: [Stat: Int] = [:]
    var ratings: [Stat: Int] = [:]
    var ovr = 0
    var counters = Counters()
    var programDay: Int? = nil
    /// Ids of all live XP entries, for quick "is this done?" checks via stable ids.
    var activeIDs = Set<UUID>()

    init(today: String) { self.today = today }

    func rating(_ stat: Stat) -> Int { ratings[stat] ?? 0 }
    var nextRank: Rank? { Ranks.next(after: rank) }
    var levelsToNextRank: Int? { nextRank.map { $0.minLevel - level.level } }
    var weakestStat: Stat { Stat.radarOrder.min { rating($0) < rating($1) } ?? .discipline }
    var strongestStat: Stat { Stat.radarOrder.max { rating($0) < rating($1) } ?? .physical }

    func state(_ day: String) -> DayState {
        if Day.number(day) > Day.number(today) { return .future }
        return states[day] ?? .empty
    }
}

enum Engine {
    private struct HabitWindow {
        let id: String
        let from: Int
        let until: Int
        let weekdays: Set<Int>
    }

    /// Stat rating 1...99: starting baseline + lifetime growth + recent consistency (last 14 days).
    static func rating(baseline: Int, statXP: Int, recentXP: Int) -> Int {
        let growth = 40 * (1 - exp(-Double(max(statXP, 0)) / 4000))
        let consistency = 25 * min(1, Double(max(recentXP, 0)) / 350)
        return min(99, max(1, Int((Double(baseline) + growth + consistency).rounded())))
    }

    static let ratingWindow = 14

    static func snapshot(_ data: AppData, today: String) -> Snapshot {
        var s = Snapshot(today: today)
        let todayN = Day.number(today)
        let recentFrom = todayN - (ratingWindow - 1)
        let calendar = Calendar.current

        var total = 0
        var statXP: [Stat: Int] = [:]
        var recent: [Stat: Int] = [:]
        var completed = Set<String>()
        var counters = Counters()
        var nutritionDays = Set<String>()

        for e in data.entries where !e.deleted {
            s.activeIDs.insert(e.id)
            total += e.xp
            statXP[e.stat, default: 0] += e.xp
            let dn = Day.number(e.day)
            if e.xp > 0 && dn >= recentFrom && dn <= todayN { recent[e.stat, default: 0] += e.xp }
            if e.day == today { s.xpToday += e.xp }
            switch e.kind {
            case .habit:
                completed.insert(e.ref + "|" + e.day)
                counters.tasksCompleted += 1
                if calendar.component(.hour, from: e.date) < 8 { counters.earlyBird += 1 }
            case .challenge:
                counters.challenges += 1
                if calendar.component(.hour, from: e.date) < 8 { counters.earlyBird += 1 }
            case .focus:
                counters.focusMinutes += Int(e.quantity)
                counters.focusSessions += 1
            case .breathe: counters.breathSessions += 1
            case .arcBonus: counters.arcsConquered += 1
            case .nutrition: nutritionDays.insert(e.day)
            case .program: counters.programsCompleted += 1
            case .affirmation: counters.affirmationDays += 1
            default: break
            }
            switch e.kind {
            case .habit, .challenge, .focus, .breathe, .journal, .workout, .arc, .affirmation:
                if e.xp > 0 { counters.statActivities[e.stat, default: 0] += 1 }
            default: break
            }
        }

        // Day-by-day records, streak and shields.
        let windows = data.habits.map { h in
            HabitWindow(id: h.id.uuidString,
                        from: Day.number(h.createdDay),
                        until: h.deleted ? Day.number(h.updatedAt) - 1 : Int.max,
                        weekdays: Set(h.weekdays))
        }
        let rule = data.settings.streakRule
        let startN = min(Day.number(data.profile.startDay), todayN)
        var streak = 0
        var best = 0
        var shields = 0

        func win() {
            streak += 1
            best = max(best, streak)
            if streak % 7 == 0 { shields = min(2, shields + 1) }
        }

        for dn in startN...todayN {
            let key = Day.key(dn)
            let weekday = Day.weekday(number: dn)
            var rec = DayRecord()
            for w in windows where dn >= w.from && dn <= w.until && w.weekdays.contains(weekday) {
                rec.scheduled += 1
                if completed.contains(w.id + "|" + key) { rec.done += 1 }
            }
            s.records[key] = rec
            let secured = rule.secured(done: rec.done, scheduled: rec.scheduled)
            let perfect = rec.scheduled > 0 && rec.done >= rec.scheduled
            let state: DayState
            if rec.scheduled == 0 {
                state = .empty
            } else if secured {
                win()
                state = perfect ? .perfect : .secured
            } else if dn == todayN {
                state = rec.done > 0 ? .partial : .pending
            } else if shields > 0 {
                shields -= 1
                state = .shielded
            } else {
                streak = 0
                state = .missed
            }
            s.states[key] = state
            if perfect { counters.perfectDays += 1 }
            if secured { counters.securedDays += 1 }
        }

        // Perfect weeks: every scheduled day of a finished Mon-Sun week fully completed (5+ active days).
        var week = Day.number(Day.weekStart(Day.key(startN)))
        while week + 6 <= todayN {
            var active = 0
            var allDone = true
            for dn in week...(week + 6) {
                guard let rec = s.records[Day.key(dn)], rec.scheduled > 0 else { continue }
                active += 1
                if rec.done < rec.scheduled { allDone = false }
            }
            if allDone && active >= 5 { counters.perfectWeeks += 1 }
            week += 7
        }

        counters.journalEntries = data.journal.filter { !$0.deleted }.count
        counters.workouts = data.workouts.filter { !$0.deleted }.count
        counters.nutritionDays = nutritionDays.count

        var ratings: [Stat: Int] = [:]
        for stat in Stat.allCases {
            ratings[stat] = rating(baseline: data.profile.baseline(for: stat),
                                   statXP: statXP[stat] ?? 0,
                                   recentXP: recent[stat] ?? 0)
        }

        s.totalXP = max(total, 0)
        s.level = Leveling.state(totalXP: total)
        s.rank = Ranks.rank(forLevel: s.level.level)
        s.stage = Evolution.stage(forLevel: s.level.level)
        s.streak = streak
        s.bestStreak = best
        s.shields = shields
        s.multiplier = StreakBonus.multiplier(streak: streak)
        s.todayRecord = s.records[today] ?? DayRecord()
        s.todaySecured = s.states[today]?.isWin ?? false
        s.statXP = statXP
        s.ratings = ratings
        s.ovr = Int((Double(ratings.values.reduce(0, +)) / Double(Stat.allCases.count)).rounded())
        s.counters = counters
        if let p = data.program, !p.ended {
            s.programDay = Day.diff(p.startDay, today) + 1
        }
        return s
    }

    // MARK: History

    struct DailyXP: Identifiable, Hashable {
        var day: String
        var stat: Stat
        var xp: Int
        var id: String { day + stat.rawValue }
    }

    /// XP per day and stat over the last `days` days (positive gains only).
    static func dailyXP(_ data: AppData, days: Int, today: String) -> [DailyXP] {
        let to = Day.number(today)
        let from = to - days + 1
        var buckets: [String: Int] = [:]
        for e in data.entries where !e.deleted && e.xp > 0 {
            let dn = Day.number(e.day)
            guard dn >= from && dn <= to else { continue }
            buckets[e.day + "|" + e.stat.rawValue, default: 0] += e.xp
        }
        var out: [DailyXP] = []
        for dn in from...to {
            let key = Day.key(dn)
            for stat in Stat.radarOrder {
                if let xp = buckets[key + "|" + stat.rawValue] { out.append(DailyXP(day: key, stat: stat, xp: xp)) }
            }
        }
        return out
    }

    struct RatingPoint: Identifiable, Hashable {
        var day: String
        var rating: Int
        var id: String { day }
    }

    /// The stat's rating at the end of each of the last `days` days.
    static func ratingHistory(_ data: AppData, stat: Stat, days: Int, today: String) -> [RatingPoint] {
        let to = Day.number(today)
        let from = to - days + 1
        var perDay: [Int: Int] = [:]
        var before = 0
        for e in data.entries where !e.deleted && e.stat == stat {
            let dn = Day.number(e.day)
            if dn < from - ratingWindow { before += e.xp } else { perDay[dn, default: 0] += e.xp }
        }
        var cumulative = before
        for dn in (from - ratingWindow)..<from { cumulative += perDay[dn] ?? 0 }
        var out: [RatingPoint] = []
        for dn in from...to {
            cumulative += perDay[dn] ?? 0
            var recent = 0
            for r in (dn - ratingWindow + 1)...dn { recent += max(perDay[r] ?? 0, 0) }
            out.append(RatingPoint(day: Day.key(dn),
                                   rating: rating(baseline: data.profile.baseline(for: stat), statXP: cumulative, recentXP: recent)))
        }
        return out
    }

    /// The date each level was first reached.
    static func levelDates(_ data: AppData) -> [Int: Date] {
        var out: [Int: Date] = [1: data.profile.createdAt]
        var cumulative = 0
        var level = 1
        for e in data.entries.filter({ !$0.deleted }).sorted(by: { $0.date < $1.date }) {
            cumulative += e.xp
            while cumulative >= Leveling.totalXP(toReach: level + 1) {
                level += 1
                if out[level] == nil { out[level] = e.date }
            }
        }
        return out
    }
}

// MARK: - Achievements

struct AchievementDef: Identifiable {
    let key: String
    let name: String
    let detail: String // "{n}" is replaced with the threshold
    let symbol: String
    let stat: Stat
    let thresholds: [Int]
    let metric: (Snapshot) -> Int

    var id: String { key }

    func tier(for value: Int) -> Int { thresholds.filter { value >= $0 }.count }

    func description(tier: Int) -> String {
        let t = thresholds[min(max(tier, 1), thresholds.count) - 1]
        return detail.replacingOccurrences(of: "{n}", with: String(t))
            .replacingOccurrences(of: "{s}", with: t == 1 ? "" : "s")
    }
}

enum Achievements {
    static func bonusXP(tier: Int) -> Int { [25, 60, 150][min(max(tier, 1), 3) - 1] }

    static let all: [AchievementDef] = [
        AchievementDef(key: "ironwill", name: "Iron Will", detail: "Reach a {n}-day streak", symbol: "flame.fill", stat: .discipline, thresholds: [7, 30, 100]) { $0.bestStreak },
        AchievementDef(key: "earlybird", name: "Early Bird", detail: "Complete {n} tasks before 8 AM", symbol: "sunrise.fill", stat: .discipline, thresholds: [5, 25, 100]) { $0.counters.earlyBird },
        AchievementDef(key: "centurion", name: "Centurion", detail: "Complete {n} tasks", symbol: "checkmark.seal.fill", stat: .discipline, thresholds: [100, 500, 2000]) { $0.counters.tasksCompleted },
        AchievementDef(key: "perfectweek", name: "Perfect Week", detail: "Finish {n} perfect week{s}", symbol: "star.fill", stat: .discipline, thresholds: [1, 4, 12]) { $0.counters.perfectWeeks },
        AchievementDef(key: "beast", name: "Beast Mode", detail: "Complete {n} Physical activities", symbol: "figure.strengthtraining.traditional", stat: .physical, thresholds: [10, 50, 200]) { $0.counters.statActivities[.physical] ?? 0 },
        AchievementDef(key: "connector", name: "The Connector", detail: "Complete {n} Social activities", symbol: "person.2.fill", stat: .social, thresholds: [10, 50, 150]) { $0.counters.statActivities[.social] ?? 0 },
        AchievementDef(key: "zen", name: "Zen Mind", detail: "Complete {n} Mental activities", symbol: "brain.head.profile", stat: .mental, thresholds: [10, 50, 150]) { $0.counters.statActivities[.mental] ?? 0 },
        AchievementDef(key: "scholar", name: "The Scholar", detail: "Complete {n} Intellect activities", symbol: "book.fill", stat: .intellect, thresholds: [10, 50, 150]) { $0.counters.statActivities[.intellect] ?? 0 },
        AchievementDef(key: "visionary", name: "Visionary", detail: "Complete {n} Ambition activities", symbol: "scope", stat: .ambition, thresholds: [10, 50, 150]) { $0.counters.statActivities[.ambition] ?? 0 },
        AchievementDef(key: "deepwork", name: "Deep Work", detail: "Lock in for {n} minutes total", symbol: "timer", stat: .ambition, thresholds: [120, 1000, 5000]) { $0.counters.focusMinutes },
        AchievementDef(key: "challenger", name: "Challenger", detail: "Complete {n} daily challenges", symbol: "bolt.fill", stat: .ambition, thresholds: [5, 25, 100]) { $0.counters.challenges },
        AchievementDef(key: "arcs", name: "Arc Conqueror", detail: "Conquer {n} arc{s}", symbol: "mountain.2.fill", stat: .discipline, thresholds: [1, 3, 6]) { $0.counters.arcsConquered },
        AchievementDef(key: "lifter", name: "Iron Lifter", detail: "Log {n} workouts", symbol: "dumbbell.fill", stat: .physical, thresholds: [5, 25, 100]) { $0.counters.workouts },
        AchievementDef(key: "fuel", name: "Fuel Master", detail: "Hit a nutrition goal on {n} days", symbol: "fork.knife", stat: .physical, thresholds: [7, 30, 100]) { $0.counters.nutritionDays },
        AchievementDef(key: "chronicler", name: "Chronicler", detail: "Write {n} journal entries", symbol: "book.closed.fill", stat: .mental, thresholds: [7, 30, 100]) { $0.counters.journalEntries },
        AchievementDef(key: "breath", name: "Breathwork", detail: "Complete {n} breathing sessions", symbol: "wind", stat: .mental, thresholds: [5, 25, 100]) { $0.counters.breathSessions },
        AchievementDef(key: "mirror", name: "The Mirror", detail: "Recite affirmations on {n} days", symbol: "person.crop.square", stat: .mental, thresholds: [3, 21, 60]) { $0.counters.affirmationDays },
        AchievementDef(key: "graduate", name: "Graduate", detail: "Complete {n} 60-day program{s}", symbol: "graduationcap.fill", stat: .ambition, thresholds: [1, 2, 4]) { $0.counters.programsCompleted },
        AchievementDef(key: "ascension", name: "Ascension", detail: "Reach level {n}", symbol: "crown.fill", stat: .ambition, thresholds: [10, 50, 100]) { $0.level.level },
    ]

    static func def(_ key: String) -> AchievementDef? { all.first { $0.key == key } }
}
