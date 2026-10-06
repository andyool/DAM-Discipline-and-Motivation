import Foundation

// MARK: - Stats

/// The six attributes that make up your OVR rating.
enum Stat: String, Codable, CaseIterable, Identifiable, Hashable {
    case physical, social, discipline, mental, intellect, ambition

    var id: String { rawValue }
    var name: String { rawValue.capitalized }

    /// Order of the radar chart, clockwise from the top.
    static let radarOrder: [Stat] = [.physical, .social, .discipline, .mental, .intellect, .ambition]

    var symbol: String {
        switch self {
        case .physical: return "figure.run"
        case .social: return "person.2.fill"
        case .discipline: return "flame.fill"
        case .mental: return "brain.head.profile"
        case .intellect: return "book.fill"
        case .ambition: return "scope"
        }
    }

    var tagline: String {
        switch self {
        case .physical: return "Strength, energy, health."
        case .social: return "Confidence, connection, presence."
        case .discipline: return "Doing it when you don't feel like it."
        case .mental: return "Calm, clarity, resilience."
        case .intellect: return "Learning, reading, thinking."
        case .ambition: return "Goals, focus, building your future."
        }
    }

    var improveTip: String {
        switch self {
        case .physical: return "Train, walk, stretch, hit your protein. Log workouts in the Lift tracker."
        case .social: return "Start conversations, call people, make plans. Small reps build confidence."
        case .discipline: return "Wake on time, cut screen time, take the cold shower. Keep your word to yourself."
        case .mental: return "Meditate, breathe, journal. Use the Breathe tool for guided sessions."
        case .intellect: return "Read daily, study, learn a skill. Lock In sessions can count toward Intellect."
        case .ambition: return "Deep work on your goals, plan tomorrow, write your vision."
        }
    }
}

enum Difficulty: Int, Codable, CaseIterable, Identifiable, Hashable {
    case easy = 1, medium, hard, savage

    var id: Int { rawValue }

    var xp: Int {
        switch self {
        case .easy: return 10
        case .medium: return 20
        case .hard: return 35
        case .savage: return 50
        }
    }

    var label: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        case .savage: return "Savage"
        }
    }
}

// MARK: - Sync

/// Every stored record carries an id and a modification time so two devices can be merged.
protocol Syncable: Identifiable, Codable where ID: Hashable & Codable {
    var updatedAt: Date { get }
}

enum Merge {
    /// Union by id; on conflict the most recently updated record wins.
    static func records<T: Syncable>(_ a: [T], _ b: [T]) -> [T] {
        var result = a
        var index: [T.ID: Int] = [:]
        for (i, item) in a.enumerated() { index[item.id] = i }
        for item in b {
            if let i = index[item.id] {
                if item.updatedAt > result[i].updatedAt { result[i] = item }
            } else {
                index[item.id] = result.count
                result.append(item)
            }
        }
        return result
    }
}

// MARK: - Habits

struct HabitStage: Codable, Hashable {
    /// First program day (1-based) this stage applies to.
    var fromDay: Int
    /// Titles rotate daily within the stage.
    var titles: [String]
    var difficulty: Difficulty
}

struct Habit: Syncable, Hashable {
    var id: UUID = UUID()
    var title: String
    var stat: Stat
    var difficulty: Difficulty
    /// Calendar weekdays (1 = Sunday ... 7 = Saturday) the habit is scheduled on.
    var weekdays: [Int] = [1, 2, 3, 4, 5, 6, 7]
    /// Optional reminder, minutes after midnight.
    var reminder: Int? = nil
    /// Program habits evolve over the 60 days.
    var stages: [HabitStage] = []
    var programID: UUID? = nil
    var createdDay: String
    var order: Int = 0
    var updatedAt: Date = Date()
    var deleted: Bool = false

    var isProgram: Bool { programID != nil }
    var isDaily: Bool { Set(weekdays).count == 7 }

    func isScheduled(weekday: Int) -> Bool { weekdays.contains(weekday) }

    func stage(programDay: Int?) -> HabitStage? {
        guard let day = programDay, !stages.isEmpty else { return nil }
        return stages.filter { $0.fromDay <= max(day, 1) }.max { $0.fromDay < $1.fromDay } ?? stages.first
    }

    func title(programDay: Int?) -> String {
        guard let day = programDay, let stage = stage(programDay: day), !stage.titles.isEmpty else { return title }
        return stage.titles[(max(day, 1) - 1) % stage.titles.count]
    }

    func difficulty(programDay: Int?) -> Difficulty {
        stage(programDay: programDay)?.difficulty ?? difficulty
    }

    var scheduleLabel: String {
        let set = Set(weekdays)
        if set.count == 7 { return "Every day" }
        if set == [2, 3, 4, 5, 6] { return "Weekdays" }
        if set == [1, 7] { return "Weekends" }
        return [2, 3, 4, 5, 6, 7, 1].filter { set.contains($0) }.map { Day.weekdayNames[$0 - 1] }.joined(separator: " ")
    }
}

// MARK: - XP ledger

enum EntryKind: String, Codable, Hashable {
    case habit, challenge, arc, arcBonus, focus, breathe, journal, workout, pr, nutrition, achievement, penalty, program, affirmation
}

/// Every bit of XP earned is an entry. Totals, levels, stats and streak bonuses are derived from these.
struct XPEntry: Syncable, Hashable {
    var id: UUID
    var kind: EntryKind
    var ref: String
    var day: String
    var date: Date
    var stat: Stat
    var xp: Int
    var title: String
    var quantity: Double = 0
    var updatedAt: Date
    var deleted: Bool = false
}

// MARK: - Journal

enum JournalKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case morning, evening, free
    var id: String { rawValue }

    var name: String {
        switch self {
        case .morning: return "Morning"
        case .evening: return "Evening"
        case .free: return "Free write"
        }
    }

    var symbol: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .evening: return "moon.stars.fill"
        case .free: return "pencil.line"
        }
    }

    var stat: Stat {
        switch self {
        case .morning: return .ambition
        case .evening, .free: return .mental
        }
    }

    var xp: Int { self == .free ? 10 : 15 }
}

struct JournalEntry: Syncable, Hashable {
    var id: UUID = UUID()
    var kind: JournalKind
    var day: String
    var date: Date
    var mood: Int = 3
    var prompts: [String]
    var answers: [String]
    var updatedAt: Date = Date()
    var deleted: Bool = false

    var preview: String {
        answers.first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? ""
    }
}

// MARK: - Workouts

struct SetLog: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var reps: Int
    var weight: Double
    var done: Bool = false

    /// Epley estimated one-rep max.
    var estimatedMax: Double { weight * (1 + Double(reps) / 30) }
}

struct ExerciseLog: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var sets: [SetLog]
}

struct WorkoutLog: Syncable, Hashable {
    var id: UUID = UUID()
    var name: String
    var day: String
    var date: Date
    var durationSeconds: Int = 0
    var exercises: [ExerciseLog]
    var updatedAt: Date = Date()
    var deleted: Bool = false

    var completedSets: Int { exercises.reduce(0) { $0 + $1.sets.filter(\.done).count } }
    var volume: Double {
        exercises.reduce(0) { total, ex in total + ex.sets.filter(\.done).reduce(0) { $0 + Double($1.reps) * $1.weight } }
    }
}

struct WorkoutTemplate: Syncable, Hashable {
    var id: UUID = UUID()
    var name: String
    var exercises: [String]
    var builtIn: Bool = false
    var updatedAt: Date = Date()
    var deleted: Bool = false
}

// MARK: - Nutrition

struct Meal: Syncable, Hashable {
    var id: UUID = UUID()
    var day: String
    var date: Date
    var name: String
    var calories: Int
    var protein: Int
    var updatedAt: Date = Date()
    var deleted: Bool = false
}

/// A per-day counter (water glasses).
struct DayCount: Syncable, Hashable {
    var id: String // day key
    var value: Int
    var updatedAt: Date = Date()
}

// MARK: - Challenges

struct ChallengeAccept: Syncable, Hashable {
    var id: String // "key|day"
    var key: String
    var day: String
    var updatedAt: Date = Date()
    var deleted: Bool = false
}

struct ArcRun: Syncable, Hashable {
    var id: UUID = UUID()
    var templateID: String
    var startDay: String
    var length: Int
    var startedAt: Date = Date()
    var finishedDay: String? = nil
    var conquered: Bool = false
    var abandoned: Bool = false
    var updatedAt: Date = Date()
    var deleted: Bool = false

    var endDay: String { Day.add(length - 1, to: startDay) }
    var isActive: Bool { finishedDay == nil && !abandoned && !deleted }
}

struct ArcCheckin: Syncable, Hashable {
    var id: String // "runID|day"
    var runID: UUID
    var day: String
    var value: Double
    var updatedAt: Date = Date()
    var deleted: Bool = false
}

struct AchievementUnlock: Syncable, Hashable {
    var id: String // "key-tier"
    var key: String
    var tier: Int
    var date: Date
    var updatedAt: Date = Date()
}

// MARK: - Program

enum Intensity: String, Codable, CaseIterable, Identifiable, Hashable {
    case steady, lockedIn, savage
    var id: String { rawValue }

    var name: String {
        switch self {
        case .steady: return "Steady"
        case .lockedIn: return "Locked In"
        case .savage: return "Savage"
        }
    }

    var blurb: String {
        switch self {
        case .steady: return "Build the foundation. Fewer, lighter tasks that grow over time."
        case .lockedIn: return "The real deal. A full daily routine across every area."
        case .savage: return "No mercy. Cold showers, deep work, 10k steps. Become unrecognizable."
        }
    }
}

struct Program: Codable, Hashable {
    var id: UUID = UUID()
    var number: Int = 1
    var startDay: String
    var length: Int = 60
    var intensity: Intensity
    var focus: [Stat]
    var ended: Bool = false
    var updatedAt: Date = Date()

    var endDay: String { Day.add(length - 1, to: startDay) }

    static let phases: [(name: String, from: Int)] = [("Foundation", 1), ("Build", 21), ("Forge", 41)]

    static func phase(for day: Int) -> Int {
        phases.lastIndex { $0.from <= day } ?? 0
    }
}

// MARK: - Profile & settings

enum StreakRule: String, Codable, CaseIterable, Identifiable, Hashable {
    case any, half, all
    var id: String { rawValue }

    var name: String {
        switch self {
        case .any: return "At least 1 task"
        case .half: return "Half your tasks"
        case .all: return "Every task"
        }
    }

    func secured(done: Int, scheduled: Int) -> Bool {
        guard scheduled > 0 else { return false }
        switch self {
        case .any: return done >= 1
        case .half: return done * 2 >= scheduled
        case .all: return done >= scheduled
        }
    }
}

enum WeightUnit: String, Codable, CaseIterable, Identifiable, Hashable {
    case kg, lb
    var id: String { rawValue }
}

struct Profile: Codable, Hashable {
    var name: String = ""
    var onboarded: Bool = false
    var createdAt: Date = Date()
    var startDay: String = Day.today()
    /// Starting stat ratings from the onboarding assessment, keyed by Stat raw value.
    var baseline: [String: Int] = [:]
    var theme: EvolutionTheme = .hunter
    var wakeMinutes: Int = 7 * 60
    var maxCelebratedLevel: Int = 1
    var lastProcessedDay: String = Day.today()
    var updatedAt: Date = Date()

    func baseline(for stat: Stat) -> Int { baseline[stat.rawValue] ?? 30 }
}

extension Profile {
    enum CodingKeys: String, CodingKey {
        case name, onboarded, createdAt, startDay, baseline, theme, wakeMinutes, maxCelebratedLevel, lastProcessedDay, updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Profile()
        name = c.value(.name, d.name)
        onboarded = c.value(.onboarded, d.onboarded)
        createdAt = c.value(.createdAt, d.createdAt)
        startDay = c.value(.startDay, d.startDay)
        baseline = c.value(.baseline, d.baseline)
        theme = c.value(.theme, d.theme)
        wakeMinutes = c.value(.wakeMinutes, d.wakeMinutes)
        maxCelebratedLevel = c.value(.maxCelebratedLevel, d.maxCelebratedLevel)
        lastProcessedDay = c.value(.lastProcessedDay, d.lastProcessedDay)
        updatedAt = c.value(.updatedAt, d.updatedAt)
    }
}

struct Settings: Codable, Hashable {
    var soundOn: Bool = true
    var hapticsOn: Bool = true
    var streakRule: StreakRule = .half
    var hardcore: Bool = false
    var morningReminder: Bool = true
    var morningMinutes: Int = 8 * 60
    var eveningReminder: Bool = true
    var eveningMinutes: Int = 20 * 60 + 30
    var calorieGoal: Int = 2400
    var proteinGoal: Int = 150
    var waterGoal: Int = 8
    var weightUnit: WeightUnit = .kg
    var focusStat: Stat = .ambition
    var focusMinutes: Int = 25
    var syncBookmark: Data? = nil
    var updatedAt: Date = Date()
}

extension Settings {
    enum CodingKeys: String, CodingKey {
        case soundOn, hapticsOn, streakRule, hardcore, morningReminder, morningMinutes, eveningReminder, eveningMinutes
        case calorieGoal, proteinGoal, waterGoal, weightUnit, focusStat, focusMinutes, syncBookmark, updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Settings()
        soundOn = c.value(.soundOn, d.soundOn)
        hapticsOn = c.value(.hapticsOn, d.hapticsOn)
        streakRule = c.value(.streakRule, d.streakRule)
        hardcore = c.value(.hardcore, d.hardcore)
        morningReminder = c.value(.morningReminder, d.morningReminder)
        morningMinutes = c.value(.morningMinutes, d.morningMinutes)
        eveningReminder = c.value(.eveningReminder, d.eveningReminder)
        eveningMinutes = c.value(.eveningMinutes, d.eveningMinutes)
        calorieGoal = c.value(.calorieGoal, d.calorieGoal)
        proteinGoal = c.value(.proteinGoal, d.proteinGoal)
        waterGoal = c.value(.waterGoal, d.waterGoal)
        weightUnit = c.value(.weightUnit, d.weightUnit)
        focusStat = c.value(.focusStat, d.focusStat)
        focusMinutes = c.value(.focusMinutes, d.focusMinutes)
        syncBookmark = c.value(.syncBookmark, d.syncBookmark)
        updatedAt = c.value(.updatedAt, d.updatedAt)
    }
}

// MARK: - Root document

struct AppData: Codable {
    var version: Int = 1
    var profile = Profile()
    var settings = Settings()
    var program: Program? = nil
    var habits: [Habit] = []
    var entries: [XPEntry] = []
    var journal: [JournalEntry] = []
    var workouts: [WorkoutLog] = []
    var templates: [WorkoutTemplate] = []
    var meals: [Meal] = []
    var water: [DayCount] = []
    var accepts: [ChallengeAccept] = []
    var arcs: [ArcRun] = []
    var arcCheckins: [ArcCheckin] = []
    var unlocks: [AchievementUnlock] = []
    var affirmations: [String] = []

    init() {}

    enum CodingKeys: String, CodingKey {
        case version, profile, settings, program, habits, entries, journal, workouts, templates, meals, water
        case accepts, arcs, arcCheckins, unlocks, affirmations
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = c.value(.version, 1)
        profile = try c.decode(Profile.self, forKey: .profile)
        settings = c.value(.settings, Settings())
        program = c.value(.program, nil)
        habits = c.value(.habits, [])
        entries = c.value(.entries, [])
        journal = c.value(.journal, [])
        workouts = c.value(.workouts, [])
        templates = c.value(.templates, [])
        meals = c.value(.meals, [])
        water = c.value(.water, [])
        accepts = c.value(.accepts, [])
        arcs = c.value(.arcs, [])
        arcCheckins = c.value(.arcCheckins, [])
        unlocks = c.value(.unlocks, [])
        affirmations = c.value(.affirmations, [])
    }

    /// Merges another copy of the data (e.g. from another device) into this one.
    func merged(with other: AppData) -> AppData {
        var out = self
        if other.profile.updatedAt > profile.updatedAt { out.profile = other.profile }
        out.profile.maxCelebratedLevel = max(profile.maxCelebratedLevel, other.profile.maxCelebratedLevel)
        out.profile.lastProcessedDay = max(profile.lastProcessedDay, other.profile.lastProcessedDay)
        out.profile.onboarded = profile.onboarded || other.profile.onboarded
        if other.settings.updatedAt > settings.updatedAt {
            let bookmark = settings.syncBookmark // bookmarks are device-specific
            out.settings = other.settings
            out.settings.syncBookmark = bookmark
        }
        switch (program, other.program) {
        case let (a?, b?): out.program = b.updatedAt > a.updatedAt ? b : a
        case let (nil, b?): out.program = b
        default: break
        }
        out.habits = Merge.records(habits, other.habits)
        out.entries = Merge.records(entries, other.entries)
        out.journal = Merge.records(journal, other.journal)
        out.workouts = Merge.records(workouts, other.workouts)
        out.templates = Merge.records(templates, other.templates)
        out.meals = Merge.records(meals, other.meals)
        out.water = Merge.records(water, other.water)
        out.accepts = Merge.records(accepts, other.accepts)
        out.arcs = Merge.records(arcs, other.arcs)
        out.arcCheckins = Merge.records(arcCheckins, other.arcCheckins)
        out.unlocks = Merge.records(unlocks, other.unlocks)
        if other.profile.updatedAt > profile.updatedAt { out.affirmations = other.affirmations }
        return out
    }
}
