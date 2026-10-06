import Foundation
import Observation

/// Lightweight events the UI turns into sounds and haptics.
enum FeedbackEvent: Equatable {
    case taskDone(combo: Int)
    case taskUndone
    case xpGain
    case focusDone
}

/// Big moments that get a full-screen or banner celebration, shown one at a time.
enum Celebration: Identifiable, Equatable {
    case levelUp(level: Int, rank: Rank?, form: String?, stage: Int)
    case daySecured(streak: Int, multiplier: Double, perfect: Bool)
    case programComplete(number: Int, rate: Int, xp: Int)
    case arcConquered(name: String, xp: Int)
    case personalRecords([String])

    var id: String {
        switch self {
        case let .levelUp(level, _, _, _): return "level-\(level)"
        case let .daySecured(streak, _, _): return "secured-\(streak)"
        case let .programComplete(number, _, _): return "program-\(number)"
        case let .arcConquered(name, _): return "arc-\(name)"
        case let .personalRecords(names): return "pr-" + names.joined()
        }
    }
}

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let subtitle: String
    let symbol: String
    let stat: Stat
    let tier: Int
}

/// A row in today's task list.
struct TaskItem: Identifiable, Hashable {
    enum Source: Hashable {
        case habit(UUID)
        case challenge(String)
    }

    let source: Source
    let title: String
    let stat: Stat
    let xp: Int
    let done: Bool
    let isProgram: Bool
    let schedule: String

    var id: String {
        switch source {
        case .habit(let id): return id.uuidString
        case .challenge(let key): return "challenge-" + key
        }
    }

    var isChallenge: Bool {
        if case .challenge = source { return true }
        return false
    }
}

struct ArcProgress: Hashable {
    var dayNumber: Int
    var checked: Int
    var metricTotal: Double
    var xp: Int
    var checkedToday: Bool
    var end: Date
    var rate: Double
}

// MARK: - Focus timer

@MainActor
@Observable
final class FocusController {
    enum Phase: Equatable { case idle, running, paused }

    private(set) var phase: Phase = .idle
    private(set) var duration: TimeInterval = 25 * 60
    private(set) var endDate: Date? = nil
    private(set) var pausedRemaining: TimeInterval = 0
    var label: String = ""
    var stat: Stat = .ambition
    /// Increments each time a session runs to completion (lets views celebrate).
    private(set) var completedCount = 0

    func remaining(at now: Date = Date()) -> TimeInterval {
        switch phase {
        case .idle: return duration
        case .paused: return pausedRemaining
        case .running: return max((endDate ?? now).timeIntervalSince(now), 0)
        }
    }

    func progress(at now: Date = Date()) -> Double {
        duration > 0 ? 1 - remaining(at: now) / duration : 0
    }

    func setDuration(minutes: Int) {
        guard phase == .idle else { return }
        duration = TimeInterval(max(minutes, 1) * 60)
    }

    func start() {
        endDate = Date().addingTimeInterval(duration)
        phase = .running
    }

    func pause() {
        guard phase == .running else { return }
        pausedRemaining = remaining()
        phase = .paused
    }

    func resume() {
        guard phase == .paused else { return }
        endDate = Date().addingTimeInterval(pausedRemaining)
        phase = .running
    }

    /// Stops the session and returns the whole minutes completed.
    @discardableResult
    func stop() -> Int {
        let done = Int((duration - remaining()) / 60)
        phase = .idle
        endDate = nil
        return max(done, 0)
    }

    /// Returns true once, when a running session reaches zero.
    func tick(now: Date = Date()) -> Bool {
        guard phase == .running, remaining(at: now) <= 0 else { return false }
        phase = .idle
        endDate = nil
        completedCount += 1
        return true
    }
}

// MARK: - App model

@MainActor
@Observable
final class AppModel {
    private(set) var data: AppData
    private(set) var snap: Snapshot
    var celebrations: [Celebration] = []
    var toasts: [Toast] = []
    let focus = FocusController()

    @ObservationIgnored var feedback: (FeedbackEvent) -> Void = { _ in }
    @ObservationIgnored var onSaved: (() -> Void)? = nil
    @ObservationIgnored private let store: Store
    @ObservationIgnored private var saveTask: Task<Void, Never>? = nil
    @ObservationIgnored private var timer: Timer? = nil

    init(store: Store = Store()) {
        self.store = store
        let loaded = store.load() ?? AppData()
        data = loaded
        snap = Engine.snapshot(loaded, today: Day.today())
        seedDefaults()
    }

    /// Loads sample history (in a throwaway store) for screenshots and test drives.
    func loadDemo(celebrate: Bool = false) {
        data = DemoData.make(today: Day.today())
        seedDefaults()
        recompute()
        evaluateAchievements()
        toasts = []
        data.profile.maxCelebratedLevel = snap.level.level
        if celebrate {
            celebrations.append(.levelUp(level: snap.level.level, rank: snap.rank, form: formName, stage: snap.stage))
        }
    }

    var today: String { snap.today }
    var theme: EvolutionTheme { data.profile.theme }
    var formName: String { theme.forms[snap.stage] }
    var settings: Settings { data.settings }
    var profile: Profile { data.profile }

    // MARK: Lifecycle

    func startClock() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    @ObservationIgnored private var lastDayCheck = Date.distantPast

    private func tick() {
        let now = Date()
        if focus.tick(now: now) {
            logFocus(minutes: Int(focus.duration / 60), stat: focus.stat, label: focus.label)
            feedback(.focusDone)
        }
        if now.timeIntervalSince(lastDayCheck) > 20 {
            lastDayCheck = now
            refreshDay()
        }
    }

    /// Re-derives everything if the calendar day changed, and settles finished arcs/programs.
    func refreshDay() {
        if Day.today() != snap.today { recompute() }
        if data.profile.onboarded && data.profile.lastProcessedDay != snap.today { processRollover() }
    }

    private func seedDefaults() {
        if data.templates.isEmpty {
            data.templates = Exercises.builtInTemplates.map { WorkoutTemplate(name: $0.0, exercises: $0.1, builtIn: true) }
        }
        if data.affirmations.isEmpty { data.affirmations = Affirmations.defaults }
    }

    private func recompute() {
        snap = Engine.snapshot(data, today: Day.today())
    }

    private func commit(celebrate: Bool = true, _ mutate: (inout AppData) -> Void) {
        let before = snap
        var copy = data
        mutate(&copy)
        data = copy
        recompute()
        if celebrate {
            evaluateAchievements()
            detectCelebrations(from: before)
        }
        scheduleSave()
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    func saveNow() {
        do {
            try store.save(data)
            onSaved?()
        } catch {
            print("DAM: save failed: \(error)")
        }
    }

    // MARK: Celebrations

    private func evaluateAchievements() {
        for _ in 0..<4 {
            let unlocked = Set(data.unlocks.map(\.id))
            var fresh: [(AchievementDef, Int)] = []
            for def in Achievements.all {
                let tier = def.tier(for: def.metric(snap))
                guard tier > 0 else { continue }
                for t in 1...tier where !unlocked.contains("\(def.key)-\(t)") { fresh.append((def, t)) }
            }
            guard !fresh.isEmpty else { return }
            let now = Date()
            var copy = data
            for (def, t) in fresh {
                copy.unlocks.append(AchievementUnlock(id: "\(def.key)-\(t)", key: def.key, tier: t, date: now))
                copy.entries.append(XPEntry(id: .stable("achievement|\(def.key)|\(t)"), kind: .achievement, ref: "\(def.key)-\(t)",
                                            day: today, date: now, stat: def.stat, xp: Achievements.bonusXP(tier: t),
                                            title: "\(def.name) \(roman(t))", updatedAt: now))
            }
            data = copy
            // One toast per achievement, for its highest new tier.
            let best = Dictionary(fresh.map { ($0.0.key, $0.1) }, uniquingKeysWith: { a, b in Swift.max(a, b) })
            for def in Achievements.all {
                guard let t = best[def.key] else { continue }
                toasts.append(Toast(title: "\(def.name) \(roman(t))".uppercased(), subtitle: def.description(tier: t),
                                    symbol: def.symbol, stat: def.stat, tier: t))
            }
            recompute()
        }
    }

    private func detectCelebrations(from before: Snapshot) {
        if snap.today == before.today && !before.todaySecured && snap.todaySecured {
            celebrations.append(.daySecured(streak: snap.streak, multiplier: snap.multiplier,
                                            perfect: snap.states[snap.today] == .perfect))
        } else if snap.today == before.today && before.states[before.today] == .secured && snap.states[snap.today] == .perfect {
            toasts.append(Toast(title: "PERFECT DAY", subtitle: "Every task done. No excuses.", symbol: "star.fill",
                                stat: .discipline, tier: 3))
        }
        let level = snap.level.level
        let oldMax = data.profile.maxCelebratedLevel
        if level > oldMax {
            let newRank = Ranks.rank(forLevel: level)
            let rankUp = newRank != Ranks.rank(forLevel: oldMax)
            let stageUp = snap.stage != Evolution.stage(forLevel: oldMax)
            celebrations.append(.levelUp(level: level, rank: rankUp ? newRank : nil,
                                         form: stageUp ? formName : nil, stage: snap.stage))
            data.profile.maxCelebratedLevel = level
        }
    }

    func dismissCelebration() {
        if !celebrations.isEmpty { celebrations.removeFirst() }
    }

    func dismissToast(_ toast: Toast) {
        toasts.removeAll { $0.id == toast.id }
    }

    // MARK: Days & program

    func canEdit(_ day: String) -> Bool {
        let d = Day.diff(day, today)
        return d == 0 || d == 1
    }

    func programDay(for day: String) -> Int? {
        guard let p = data.program else { return nil }
        return max(Day.diff(p.startDay, day) + 1, 1)
    }

    var programHabits: [Habit] {
        guard let p = data.program else { return [] }
        return data.habits.filter { $0.programID == p.id && !$0.deleted }.sorted { $0.order < $1.order }
    }

    var customHabits: [Habit] {
        data.habits.filter { $0.programID == nil && !$0.deleted }.sorted { $0.order < $1.order }
    }

    func habitTitle(_ habit: Habit, day: String) -> String {
        habit.programID == data.program?.id ? habit.title(programDay: programDay(for: day)) : habit.title(programDay: 60)
    }

    func habitDifficulty(_ habit: Habit, day: String) -> Difficulty {
        habit.programID == data.program?.id ? habit.difficulty(programDay: programDay(for: day)) : habit.difficulty(programDay: 60)
    }

    /// Habits scheduled on a day (as they existed on that day).
    func habits(on day: String) -> [Habit] {
        let dn = Day.number(day)
        let weekday = Day.weekday(number: dn)
        return data.habits.filter { h in
            let from = Day.number(h.createdDay)
            let until = h.deleted ? Day.number(h.updatedAt) - 1 : Int.max
            return dn >= from && dn <= until && h.weekdays.contains(weekday)
        }
        .sorted { ($0.isProgram ? 0 : 1, $0.order) < ($1.isProgram ? 0 : 1, $1.order) }
    }

    func isDone(_ habit: Habit, day: String) -> Bool {
        snap.activeIDs.contains(.stable("habit|\(habit.id.uuidString)|\(day)"))
    }

    func tasks(for day: String) -> [TaskItem] {
        var items = habits(on: day).map { h in
            TaskItem(source: .habit(h.id), title: habitTitle(h, day: day), stat: h.stat,
                     xp: habitDifficulty(h, day: day).xp, done: isDone(h, day: day), isProgram: h.isProgram,
                     schedule: h.scheduleLabel)
        }
        for c in Challenges.daily(for: day) where isAccepted(c.key, day: day) {
            items.append(TaskItem(source: .challenge(c.key), title: c.name + ". " + c.detail, stat: c.stat, xp: c.xp,
                                  done: isChallengeDone(c.key, day: day), isProgram: false, schedule: "Daily challenge"))
        }
        return items
    }

    func toggle(_ item: TaskItem, day: String) {
        switch item.source {
        case .habit(let id):
            if let habit = data.habits.first(where: { $0.id == id }) { toggle(habit, day: day) }
        case .challenge(let key):
            toggleChallenge(key, day: day)
        }
    }

    func toggle(_ habit: Habit, day: String) {
        guard canEdit(day) else { return }
        let id = UUID.stable("habit|\(habit.id.uuidString)|\(day)")
        let wasDone = snap.activeIDs.contains(id)
        let xp = Int((Double(habitDifficulty(habit, day: day).xp) * snap.multiplier).rounded())
        let title = habitTitle(habit, day: day)
        setEntry(id: id, active: !wasDone) {
            XPEntry(id: id, kind: .habit, ref: habit.id.uuidString, day: day, date: Date(), stat: habit.stat, xp: xp,
                    title: title, updatedAt: Date())
        }
        emitTaskFeedback(done: !wasDone, day: day)
    }

    private func emitTaskFeedback(done: Bool, day: String) {
        guard done else {
            feedback(.taskUndone)
            return
        }
        let combo = tasks(for: day).filter(\.done).count
        feedback(.taskDone(combo: combo))
    }

    /// Activates or deactivates an XP entry with a stable id.
    private func setEntry(id: UUID, active: Bool, celebrate: Bool = true, make: () -> XPEntry) {
        let fresh = make()
        commit(celebrate: celebrate) { d in
            if let i = d.entries.firstIndex(where: { $0.id == id }) {
                if active {
                    var e = fresh
                    e.deleted = false
                    d.entries[i] = e
                } else if !d.entries[i].deleted {
                    d.entries[i].deleted = true
                    d.entries[i].updatedAt = Date()
                }
            } else if active {
                d.entries.append(fresh)
            }
        }
    }

    // MARK: Habits

    func saveHabit(_ habit: Habit) {
        var h = habit
        h.updatedAt = Date()
        commit(celebrate: false) { d in
            if let i = d.habits.firstIndex(where: { $0.id == h.id }) {
                d.habits[i] = h
            } else {
                h.order = (d.habits.map(\.order).max() ?? 0) + 1
                d.habits.append(h)
            }
        }
    }

    func deleteHabit(_ habit: Habit) {
        commit(celebrate: false) { d in
            if let i = d.habits.firstIndex(where: { $0.id == habit.id }) {
                d.habits[i].deleted = true
                d.habits[i].updatedAt = Date()
            }
        }
    }

    func newHabit() -> Habit {
        Habit(title: "", stat: .discipline, difficulty: .medium, createdDay: today)
    }

    // MARK: Daily challenges

    func isAccepted(_ key: String, day: String) -> Bool {
        data.accepts.contains { $0.id == "\(key)|\(day)" && !$0.deleted }
    }

    func isChallengeDone(_ key: String, day: String) -> Bool {
        snap.activeIDs.contains(.stable("challenge|\(key)|\(day)"))
    }

    func setAccepted(_ key: String, accepted: Bool) {
        let day = today
        let id = "\(key)|\(day)"
        commit(celebrate: false) { d in
            if let i = d.accepts.firstIndex(where: { $0.id == id }) {
                d.accepts[i].deleted = !accepted
                d.accepts[i].updatedAt = Date()
            } else if accepted {
                d.accepts.append(ChallengeAccept(id: id, key: key, day: day))
            }
        }
        if !accepted && isChallengeDone(key, day: day) {
            let entryID = UUID.stable("challenge|\(key)|\(day)")
            commit(celebrate: false) { d in
                if let i = d.entries.firstIndex(where: { $0.id == entryID }) {
                    d.entries[i].deleted = true
                    d.entries[i].updatedAt = Date()
                }
            }
        }
    }

    func toggleChallenge(_ key: String, day: String) {
        guard canEdit(day), let def = Challenges.def(key) else { return }
        if !isAccepted(key, day: day) && day == today { setAccepted(key, accepted: true) }
        let id = UUID.stable("challenge|\(key)|\(day)")
        let wasDone = snap.activeIDs.contains(id)
        let xp = Int((Double(def.xp) * snap.multiplier).rounded())
        setEntry(id: id, active: !wasDone) {
            XPEntry(id: id, kind: .challenge, ref: key, day: day, date: Date(), stat: def.stat, xp: xp,
                    title: def.name, updatedAt: Date())
        }
        emitTaskFeedback(done: !wasDone, day: day)
    }

    // MARK: Arcs

    var activeArcs: [ArcRun] { data.arcs.filter(\.isActive).sorted { $0.startedAt > $1.startedAt } }
    var finishedArcs: [ArcRun] {
        data.arcs.filter { !$0.deleted && ($0.finishedDay != nil || $0.abandoned) }.sorted { $0.startedAt > $1.startedAt }
    }

    func arcProgress(_ run: ArcRun) -> ArcProgress {
        let checkins = data.arcCheckins.filter { $0.runID == run.id && !$0.deleted }
        let dayNumber = min(max(Day.diff(run.startDay, today) + 1, 1), run.length)
        let xp = data.entries.filter { !$0.deleted && $0.kind == .arc && $0.ref == run.id.uuidString }.reduce(0) { $0 + $1.xp }
        let elapsed = max(min(Day.diff(run.startDay, today) + 1, run.length), 1)
        return ArcProgress(dayNumber: dayNumber, checked: checkins.count,
                           metricTotal: checkins.reduce(0) { $0 + $1.value }, xp: xp,
                           checkedToday: checkins.contains { $0.day == today },
                           end: Day.date(Day.add(1, to: run.endDay)),
                           rate: Double(checkins.count) / Double(elapsed))
    }

    func startArc(_ template: ArcTemplate) {
        commit(celebrate: false) { d in
            d.arcs.append(ArcRun(templateID: template.id, startDay: today, length: template.days))
        }
    }

    func checkIn(_ run: ArcRun, value: Double) {
        guard let template = Arcs.template(run.templateID) else { return }
        let day = today
        let checkinID = "\(run.id.uuidString)|\(day)"
        let entryID = UUID.stable("arc|\(run.id.uuidString)|\(day)")
        let xp = Int((Double(template.checkInXP) * snap.multiplier).rounded())
        commit { d in
            if let i = d.arcCheckins.firstIndex(where: { $0.id == checkinID }) {
                d.arcCheckins[i].value = value
                d.arcCheckins[i].deleted = false
                d.arcCheckins[i].updatedAt = Date()
            } else {
                d.arcCheckins.append(ArcCheckin(id: checkinID, runID: run.id, day: day, value: value))
            }
            let entry = XPEntry(id: entryID, kind: .arc, ref: run.id.uuidString, day: day, date: Date(), stat: template.stat,
                                xp: xp, title: template.name, quantity: value, updatedAt: Date())
            if let i = d.entries.firstIndex(where: { $0.id == entryID }) {
                if d.entries[i].deleted { d.entries[i] = entry } else { d.entries[i].quantity = value; d.entries[i].updatedAt = Date() }
            } else {
                d.entries.append(entry)
            }
        }
        feedback(.xpGain)
    }

    func undoCheckIn(_ run: ArcRun) {
        let day = today
        let checkinID = "\(run.id.uuidString)|\(day)"
        let entryID = UUID.stable("arc|\(run.id.uuidString)|\(day)")
        commit(celebrate: false) { d in
            if let i = d.arcCheckins.firstIndex(where: { $0.id == checkinID }) {
                d.arcCheckins[i].deleted = true
                d.arcCheckins[i].updatedAt = Date()
            }
            if let i = d.entries.firstIndex(where: { $0.id == entryID }) {
                d.entries[i].deleted = true
                d.entries[i].updatedAt = Date()
            }
        }
        feedback(.taskUndone)
    }

    func abandonArc(_ run: ArcRun) {
        commit(celebrate: false) { d in
            if let i = d.arcs.firstIndex(where: { $0.id == run.id }) {
                d.arcs[i].abandoned = true
                d.arcs[i].updatedAt = Date()
            }
        }
    }

    // MARK: Rollover

    private func processRollover() {
        recompute()
        let t = snap.today
        let tn = Day.number(t)
        let states = snap.states
        let records = snap.records
        let hardcore = data.settings.hardcore
        let lastProcessed = data.profile.lastProcessedDay
        var pending: [Celebration] = []

        commit { d in
            let now = Date()
            for i in d.arcs.indices where d.arcs[i].isActive && Day.number(d.arcs[i].endDay) < tn {
                let run = d.arcs[i]
                let checked = d.arcCheckins.filter { $0.runID == run.id && !$0.deleted }.count
                let conquered = checked * 10 >= run.length * 9
                d.arcs[i].finishedDay = t
                d.arcs[i].conquered = conquered
                d.arcs[i].updatedAt = now
                if conquered, let template = Arcs.template(run.templateID) {
                    d.entries.append(XPEntry(id: .stable("arcbonus|\(run.id.uuidString)"), kind: .arcBonus, ref: run.id.uuidString,
                                             day: t, date: now, stat: template.stat, xp: template.conquestXP,
                                             title: "\(template.name) conquered", updatedAt: now))
                    pending.append(.arcConquered(name: template.name, xp: template.conquestXP))
                }
            }

            if let p = d.program, !p.ended, Day.number(p.endDay) < tn {
                var won = 0
                for dn in Day.number(p.startDay)...Day.number(p.endDay) where states[Day.key(dn)]?.isWin == true { won += 1 }
                let rate = Int((Double(won) / Double(p.length) * 100).rounded())
                let xp = 200 + rate * 5
                d.program?.ended = true
                d.program?.updatedAt = now
                d.entries.append(XPEntry(id: .stable("program|\(p.id.uuidString)"), kind: .program, ref: p.id.uuidString,
                                         day: t, date: now, stat: .ambition, xp: xp,
                                         title: "60-Day Program #\(p.number) complete", updatedAt: now))
                pending.append(.programComplete(number: p.number, rate: rate, xp: xp))
            }

            if hardcore {
                let from = max(Day.number(lastProcessed), Day.number(d.profile.startDay))
                if from < tn {
                    for dn in from..<tn {
                        let key = Day.key(dn)
                        guard states[key] == .missed, let rec = records[key] else { continue }
                        let missing = rec.scheduled - rec.done
                        d.entries.append(XPEntry(id: .stable("penalty|\(key)"), kind: .penalty, ref: key, day: key, date: now,
                                                 stat: .discipline, xp: -10 * missing,
                                                 title: "Missed \(missing) task\(missing == 1 ? "" : "s")", updatedAt: now))
                    }
                }
            }
            d.profile.lastProcessedDay = t
        }
        celebrations.append(contentsOf: pending)
    }

    // MARK: Tools

    func logFocus(minutes: Int, stat: Stat, label: String) {
        guard minutes >= 1 else { return }
        let xp = minutes >= 5 ? min(minutes, 120) : 0
        let title = label.trimmingCharacters(in: .whitespaces).isEmpty ? "Lock In" : label
        commit { d in
            d.entries.append(XPEntry(id: UUID(), kind: .focus, ref: "focus", day: today, date: Date(), stat: stat, xp: xp,
                                     title: title, quantity: Double(minutes), updatedAt: Date()))
        }
    }

    var focusMinutesToday: Int {
        data.entries.filter { !$0.deleted && $0.kind == .focus && $0.day == today }.reduce(0) { $0 + Int($1.quantity) }
    }

    var breathSessionsToday: Int {
        data.entries.filter { !$0.deleted && $0.kind == .breathe && $0.day == today }.count
    }

    /// Returns the XP awarded (first 3 sessions a day earn XP).
    @discardableResult
    func logBreath(pattern: String, seconds: Int) -> Int {
        let xp = breathSessionsToday < 3 ? 10 : 0
        commit { d in
            d.entries.append(XPEntry(id: UUID(), kind: .breathe, ref: pattern, day: today, date: Date(), stat: .mental, xp: xp,
                                     title: pattern, quantity: Double(seconds), updatedAt: Date()))
        }
        feedback(.xpGain)
        return xp
    }

    var journalEntries: [JournalEntry] {
        data.journal.filter { !$0.deleted }.sorted { $0.date > $1.date }
    }

    func hasJournal(_ kind: JournalKind, day: String) -> Bool {
        data.journal.contains { !$0.deleted && $0.kind == kind && $0.day == day }
    }

    func saveJournal(_ entry: JournalEntry) {
        var e = entry
        e.updatedAt = Date()
        let awardID = UUID.stable("journal|\(e.kind.rawValue)|\(e.day)")
        let award = !snap.activeIDs.contains(awardID) && e.day == today
        commit { d in
            if let i = d.journal.firstIndex(where: { $0.id == e.id }) { d.journal[i] = e } else { d.journal.append(e) }
            if award {
                if let i = d.entries.firstIndex(where: { $0.id == awardID }) { d.entries.remove(at: i) }
                d.entries.append(XPEntry(id: awardID, kind: .journal, ref: e.kind.rawValue, day: e.day, date: Date(),
                                         stat: e.kind.stat, xp: e.kind.xp, title: "\(e.kind.name) journal", updatedAt: Date()))
            }
        }
        if award { feedback(.xpGain) }
    }

    func deleteJournal(_ entry: JournalEntry) {
        commit(celebrate: false) { d in
            if let i = d.journal.firstIndex(where: { $0.id == entry.id }) {
                d.journal[i].deleted = true
                d.journal[i].updatedAt = Date()
            }
        }
    }

    var workouts: [WorkoutLog] { data.workouts.filter { !$0.deleted }.sorted { $0.date > $1.date } }
    var templates: [WorkoutTemplate] { data.templates.filter { !$0.deleted } }

    /// Best estimated 1RM per exercise, optionally ignoring one workout.
    func personalBests(excluding id: UUID? = nil) -> [String: Double] {
        var best: [String: Double] = [:]
        for w in data.workouts where !w.deleted && w.id != id {
            for ex in w.exercises {
                for s in ex.sets where s.done && s.weight > 0 && s.reps > 0 {
                    best[ex.name] = max(best[ex.name] ?? 0, s.estimatedMax)
                }
            }
        }
        return best
    }

    /// The sets from the last time an exercise was logged, to prefill a new workout.
    func lastSets(for exercise: String) -> [SetLog]? {
        for w in workouts {
            if let ex = w.exercises.first(where: { $0.name == exercise }), !ex.sets.isEmpty {
                return ex.sets.map { SetLog(reps: $0.reps, weight: $0.weight) }
            }
        }
        return nil
    }

    /// Saves a finished workout, awards XP and returns the names of exercises with new PRs.
    @discardableResult
    func finishWorkout(_ workout: WorkoutLog) -> [String] {
        let previous = personalBests(excluding: workout.id)
        var prs: [String] = []
        for ex in workout.exercises {
            let best = ex.sets.filter { $0.done && $0.weight > 0 && $0.reps > 0 }.map(\.estimatedMax).max() ?? 0
            if best > 0, let old = previous[ex.name], best > old + 0.01 { prs.append(ex.name) }
        }
        var w = workout
        w.updatedAt = Date()
        let xp = min(80, 40 + 2 * w.completedSets)
        let entryID = UUID.stable("workout|\(w.id.uuidString)")
        let prID = UUID.stable("pr|\(w.id.uuidString)")
        let prCount = prs.count
        commit { d in
            if let i = d.workouts.firstIndex(where: { $0.id == w.id }) { d.workouts[i] = w } else { d.workouts.append(w) }
            d.entries.removeAll { $0.id == entryID || $0.id == prID }
            d.entries.append(XPEntry(id: entryID, kind: .workout, ref: w.id.uuidString, day: w.day, date: Date(),
                                     stat: .physical, xp: xp, title: w.name, quantity: Double(w.completedSets), updatedAt: Date()))
            if prCount > 0 {
                d.entries.append(XPEntry(id: prID, kind: .pr, ref: w.id.uuidString, day: w.day, date: Date(),
                                         stat: .physical, xp: 10 * prCount, title: "\(prCount) new PR\(prCount == 1 ? "" : "s")",
                                         updatedAt: Date()))
            }
        }
        if !prs.isEmpty { celebrations.append(.personalRecords(prs)) }
        feedback(.xpGain)
        return prs
    }

    func deleteWorkout(_ workout: WorkoutLog) {
        let ids: Set<UUID> = [.stable("workout|\(workout.id.uuidString)"), .stable("pr|\(workout.id.uuidString)")]
        commit(celebrate: false) { d in
            if let i = d.workouts.firstIndex(where: { $0.id == workout.id }) {
                d.workouts[i].deleted = true
                d.workouts[i].updatedAt = Date()
            }
            for i in d.entries.indices where ids.contains(d.entries[i].id) {
                d.entries[i].deleted = true
                d.entries[i].updatedAt = Date()
            }
        }
    }

    func saveTemplate(_ template: WorkoutTemplate) {
        var t = template
        t.updatedAt = Date()
        commit(celebrate: false) { d in
            if let i = d.templates.firstIndex(where: { $0.id == t.id }) { d.templates[i] = t } else { d.templates.append(t) }
        }
    }

    func deleteTemplate(_ template: WorkoutTemplate) {
        commit(celebrate: false) { d in
            if let i = d.templates.firstIndex(where: { $0.id == template.id }) {
                d.templates[i].deleted = true
                d.templates[i].updatedAt = Date()
            }
        }
    }

    // MARK: Nutrition

    func meals(on day: String) -> [Meal] {
        data.meals.filter { !$0.deleted && $0.day == day }.sorted { $0.date < $1.date }
    }

    func water(on day: String) -> Int { data.water.first { $0.id == day }?.value ?? 0 }

    func nutritionTotals(on day: String) -> (calories: Int, protein: Int) {
        meals(on: day).reduce((0, 0)) { ($0.0 + $1.calories, $0.1 + $1.protein) }
    }

    /// Recent distinct meals for one-tap re-logging.
    var recentMeals: [Meal] {
        var seen = Set<String>()
        var out: [Meal] = []
        for m in data.meals.filter({ !$0.deleted }).sorted(by: { $0.date > $1.date }) {
            let key = m.name.lowercased()
            if seen.insert(key).inserted { out.append(m) }
            if out.count == 8 { break }
        }
        return out
    }

    func addMeal(name: String, calories: Int, protein: Int) {
        let day = today
        commit { d in
            d.meals.append(Meal(day: day, date: Date(), name: name, calories: calories, protein: protein))
            Self.settleNutrition(&d, day: day)
        }
        feedback(.xpGain)
    }

    func deleteMeal(_ meal: Meal) {
        commit { d in
            if let i = d.meals.firstIndex(where: { $0.id == meal.id }) {
                d.meals[i].deleted = true
                d.meals[i].updatedAt = Date()
            }
            Self.settleNutrition(&d, day: meal.day)
        }
    }

    func setWater(_ glasses: Int) {
        let day = today
        commit { d in
            if let i = d.water.firstIndex(where: { $0.id == day }) {
                d.water[i].value = max(glasses, 0)
                d.water[i].updatedAt = Date()
            } else {
                d.water.append(DayCount(id: day, value: max(glasses, 0)))
            }
            Self.settleNutrition(&d, day: day)
        }
    }

    /// Awards (or takes back) the daily nutrition XP depending on whether goals are met.
    private static func settleNutrition(_ d: inout AppData, day: String) {
        let meals = d.meals.filter { !$0.deleted && $0.day == day }
        let calories = meals.reduce(0) { $0 + $1.calories }
        let protein = meals.reduce(0) { $0 + $1.protein }
        let water = d.water.first { $0.id == day }?.value ?? 0
        let goals = d.settings
        let checks: [(String, Bool, Stat, Int, String)] = [
            ("protein", goals.proteinGoal > 0 && protein >= goals.proteinGoal, .physical, 15, "Protein goal hit"),
            ("calories", goals.calorieGoal > 0 && Double(calories) >= Double(goals.calorieGoal) * 0.9
                && Double(calories) <= Double(goals.calorieGoal) * 1.1, .discipline, 10, "Calories on target"),
            ("water", goals.waterGoal > 0 && water >= goals.waterGoal, .physical, 10, "Hydrated"),
        ]
        for (key, met, stat, xp, title) in checks {
            let id = UUID.stable("nutrition|\(key)|\(day)")
            let index = d.entries.firstIndex { $0.id == id }
            if met {
                if let i = index {
                    if d.entries[i].deleted {
                        d.entries[i].deleted = false
                        d.entries[i].updatedAt = Date()
                    }
                } else {
                    d.entries.append(XPEntry(id: id, kind: .nutrition, ref: key, day: day, date: Date(), stat: stat, xp: xp,
                                             title: title, updatedAt: Date()))
                }
            } else if let i = index, !d.entries[i].deleted {
                d.entries[i].deleted = true
                d.entries[i].updatedAt = Date()
            }
        }
    }

    // MARK: Affirmations (Mirror)

    var affirmedToday: Bool { snap.activeIDs.contains(.stable("affirmation|\(today)")) }

    func completeAffirmations() {
        guard !affirmedToday else { return }
        let id = UUID.stable("affirmation|\(today)")
        setEntry(id: id, active: true) {
            XPEntry(id: id, kind: .affirmation, ref: "mirror", day: today, date: Date(), stat: .mental, xp: 15,
                    title: "Mirror affirmations", updatedAt: Date())
        }
        feedback(.xpGain)
    }

    func setAffirmations(_ list: [String]) {
        commit(celebrate: false) { d in
            d.affirmations = list
            d.profile.updatedAt = Date()
        }
    }

    // MARK: Profile & settings

    func updateSettings(_ change: (inout Settings) -> Void) {
        commit(celebrate: false) { d in
            change(&d.settings)
            d.settings.updatedAt = Date()
            Self.settleNutrition(&d, day: Day.today())
        }
    }

    func updateProfile(_ change: (inout Profile) -> Void) {
        commit(celebrate: false) { d in
            change(&d.profile)
            d.profile.updatedAt = Date()
        }
    }

    func completeOnboarding(name: String, answers: [Stat: Int], focus: [Stat], intensity: Intensity,
                            wakeMinutes: Int, theme: EvolutionTheme) {
        let t = today
        commit(celebrate: false) { d in
            d.profile.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            d.profile.baseline = Dictionary(uniqueKeysWithValues: Stat.allCases.map { ($0.rawValue, Assessment.baseline(answer: answers[$0] ?? 1)) })
            d.profile.theme = theme
            d.profile.wakeMinutes = wakeMinutes
            d.profile.onboarded = true
            d.profile.createdAt = Date()
            d.profile.startDay = t
            d.profile.lastProcessedDay = t
            d.profile.updatedAt = Date()
            let program = Program(number: 1, startDay: t, intensity: intensity, focus: focus)
            d.program = program
            d.habits.append(contentsOf: ProgramBuilder.habits(for: program, wakeMinutes: wakeMinutes))
        }
    }

    func startNewProgram(intensity: Intensity, focus: [Stat]) {
        let t = today
        let wake = data.profile.wakeMinutes
        commit { d in
            let number = (d.program?.number ?? 0) + 1
            d.program?.ended = true
            for i in d.habits.indices where d.habits[i].programID != nil && !d.habits[i].deleted {
                d.habits[i].deleted = true
                d.habits[i].updatedAt = Date()
            }
            let program = Program(number: number, startDay: t, intensity: intensity, focus: focus)
            d.program = program
            d.habits.append(contentsOf: ProgramBuilder.habits(for: program, wakeMinutes: wake))
        }
    }

    // MARK: Data management

    func exportData() throws -> Data { try Store.encoder.encode(data) }

    func importData(_ raw: Data, merge: Bool) throws {
        let incoming = try Store.decoder.decode(AppData.self, from: raw)
        data = merge ? data.merged(with: incoming) : incoming
        seedDefaults()
        recompute()
        scheduleSave()
    }

    /// Merges data from another device (sync). No celebrations for remote progress.
    /// Returns true if anything changed.
    @discardableResult
    func absorb(_ remote: AppData) -> Bool {
        let before = try? Store.encoder.encode(data)
        var merged = data.merged(with: remote)
        let level = Engine.snapshot(merged, today: Day.today()).level.level
        merged.profile.maxCelebratedLevel = max(merged.profile.maxCelebratedLevel, level)
        let after = try? Store.encoder.encode(merged)
        guard before != after else { return false }
        data = merged
        recompute()
        scheduleSave()
        return true
    }

    /// What gets written to the shared sync folder (device-specific bookmark removed).
    func syncPayload() throws -> Data {
        var copy = data
        copy.settings.syncBookmark = nil
        return try Store.encoder.encode(copy)
    }

    func resetAll() {
        data = AppData()
        celebrations = []
        toasts = []
        seedDefaults()
        recompute()
        saveNow()
    }

    // MARK: Insights

    func ratingHistory(_ stat: Stat, days: Int = 30) -> [Engine.RatingPoint] {
        Engine.ratingHistory(data, stat: stat, days: days, today: today)
    }

    func dailyXP(days: Int = 30) -> [Engine.DailyXP] { Engine.dailyXP(data, days: days, today: today) }

    func levelDates() -> [Int: Date] { Engine.levelDates(data) }

    func unlockDate(_ key: String, tier: Int) -> Date? { data.unlocks.first { $0.id == "\(key)-\(tier)" }?.date }

    func achievementTier(_ def: AchievementDef) -> Int {
        data.unlocks.filter { $0.key == def.key }.map(\.tier).max() ?? 0
    }
}
