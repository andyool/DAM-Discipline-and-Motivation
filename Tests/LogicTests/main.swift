import Foundation

var failures = 0
func check(_ cond: Bool, _ msg: String, file: String = #file, line: Int = #line) {
    if !cond { failures += 1; print("FAIL [\(line)]: \(msg)") }
}

// MARK: Day math
for n in [-1000, 0, 1, 19000, 20732, 30000] {
    check(Day.number(Day.key(n)) == n, "roundtrip \(n)")
}
check(Day.key(0) == "1970-01-01", "epoch key")
check(Day.weekday("1970-01-01") == 5, "1970-01-01 is Thursday")
check(Day.weekday("2026-10-06") == 3, "2026-10-06 is Tuesday")
check(Day.mondayIndex("2026-10-05") == 0, "monday index")
check(Day.weekStart("2026-10-11") == "2026-10-05", "week start sunday")
check(Day.diff("2026-02-27", "2026-03-01") == 2, "diff across feb")
check(Day.add(1, to: "2024-02-28") == "2024-02-29", "leap")
check(Day.headline("2026-10-06") == "Tue, Oct 6.", "headline \(Day.headline("2026-10-06"))")
check(Day.clock(7 * 60 + 45) == "7:45 AM", "clock")
check(Day.clock(0) == "12:00 AM" && Day.clock(12 * 60 + 5) == "12:05 PM", "clock edge")
check(Day.key(Day.date("2026-10-06")) == "2026-10-06", "date roundtrip")
check(UUID.stable("a") == UUID.stable("a") && UUID.stable("a") != UUID.stable("b"), "stable uuid")
check(roman(3) == "III" && roman(4) == "IV", "roman")

// MARK: Progression
print("Level XP table:")
for l in [2, 5, 10, 20, 30, 45, 60, 85, 100, 125] {
    print("  L\(l): total \(Leveling.totalXP(toReach: l)) (~\(Leveling.totalXP(toReach: l) / 130) days at 130xp/day)")
}
check(Leveling.state(totalXP: 0).level == 1, "level 1")
check(Leveling.state(totalXP: Leveling.totalXP(toReach: 7)).level == 7, "level 7 exact")
check(Leveling.state(totalXP: Leveling.totalXP(toReach: 7) - 1).level == 6, "level 6")
check(Ranks.all.count == 28, "rank count \(Ranks.all.count)")
check(Ranks.rank(forLevel: 1).name == "Iron I", "iron 1")
check(Ranks.rank(forLevel: 9).name == "Bronze I", "bronze")
check(Ranks.rank(forLevel: 130).name == "Legend", "legend")
check(Ranks.all.last?.maxLevel == nil && Ranks.all.first?.maxLevel == 2, "ranges")
print("Ranks:", Ranks.all.map { "\($0.name) \($0.levelRange)" }.joined(separator: ", "))
check(Evolution.stage(forLevel: 1) == 0 && Evolution.stage(forLevel: 5) == 1 && Evolution.stage(forLevel: 200) == 9, "evolution")
for t in EvolutionTheme.allCases { check(t.forms.count == 10, "forms \(t)") }
check(StreakBonus.label(1.5) == "x1.5" && StreakBonus.label(1) == "x1", "mult label \(StreakBonus.label(1.5))")

// MARK: Content
check(Challenges.daily(for: "2026-10-06").count == 3, "3 daily challenges")
check(Set(Challenges.daily(for: "2026-10-06").map(\.stat)).count == 3, "distinct stats")
check(Challenges.daily(for: "2026-10-06") == Challenges.daily(for: "2026-10-06"), "stable daily")
check(Set(Challenges.pool.map(\.key)).count == Challenges.pool.count, "unique challenge keys")
for i in Intensity.allCases {
    let p = Program(startDay: "2026-10-06", intensity: i, focus: Stat.allCases)
    let hs = ProgramBuilder.habits(for: p, wakeMinutes: 405)
    print("Program \(i.name): \(hs.count) habits ->", hs.map { $0.title(programDay: 1) }.joined(separator: " | "))
    print("   day 45:", hs.map { $0.title(programDay: 45) }.joined(separator: " | "))
}

// MARK: Engine streaks
func makeData(days: Int, doneOn: (Int) -> Int, habitsCount: Int = 4, rule: StreakRule = .half) -> (AppData, String) {
    var d = AppData()
    let today = Day.today()
    let start = Day.add(-(days - 1), to: today)
    d.profile.startDay = start
    d.profile.onboarded = true
    d.settings.streakRule = rule
    for i in 0..<habitsCount {
        d.habits.append(Habit(title: "H\(i)", stat: Stat.allCases[i % 6], difficulty: .medium, createdDay: start, order: i))
    }
    for k in 0..<days {
        let day = Day.add(k, to: start)
        let n = doneOn(k)
        for h in d.habits.prefix(n) {
            d.entries.append(XPEntry(id: .stable("habit|\(h.id.uuidString)|\(day)"), kind: .habit, ref: h.id.uuidString, day: day,
                                     date: Day.date(day).addingTimeInterval(9 * 3600), stat: h.stat, xp: 20, title: h.title, updatedAt: Date()))
        }
    }
    return (d, today)
}

do {
    let (d, today) = makeData(days: 10, doneOn: { _ in 4 })
    let s = Engine.snapshot(d, today: today)
    check(s.streak == 10, "streak 10 got \(s.streak)")
    check(s.bestStreak == 10, "best 10")
    check(s.shields == 1, "1 shield after 7 got \(s.shields)")
    check(s.todaySecured, "today secured")
    check(s.totalXP == 800, "xp 800 got \(s.totalXP)")
    check(s.counters.tasksCompleted == 40, "tasks")
    check(s.programDay == nil, "no program")
}
do {
    // 8 good days, miss day 8 (shield used), good day 9 => streak continues
    let (d, today) = makeData(days: 10, doneOn: { $0 == 8 ? 0 : 4 })
    let s = Engine.snapshot(d, today: today)
    check(s.states[Day.add(-1, to: today)] == .shielded, "shielded day")
    check(s.streak == 9, "streak with shield got \(s.streak)")
    check(s.shields == 0, "shield consumed")
}
do {
    // two misses in a row: second breaks
    let (d, today) = makeData(days: 12, doneOn: { ($0 == 8 || $0 == 9) ? 0 : 4 })
    let s = Engine.snapshot(d, today: today)
    check(s.streak == 2, "streak broken got \(s.streak)")
    check(s.bestStreak == 8, "best 8 got \(s.bestStreak)")
}
do {
    // today not done yet: streak from yesterday preserved, state pending
    let (d, today) = makeData(days: 5, doneOn: { $0 == 4 ? 0 : 4 })
    let s = Engine.snapshot(d, today: today)
    check(s.streak == 4, "pending today keeps streak got \(s.streak)")
    check(s.states[today] == .pending, "pending state")
    check(!s.todaySecured, "not secured")
}
do {
    // half rule: 2 of 4 secures
    let (d, today) = makeData(days: 3, doneOn: { _ in 2 })
    let s = Engine.snapshot(d, today: today)
    check(s.streak == 3 && s.states[today] == .secured, "half rule")
    var d2 = d
    d2.settings.streakRule = .all
    let s2 = Engine.snapshot(d2, today: today)
    check(s2.streak == 0, "all rule breaks: got \(s2.streak)")
}
do {
    // perfect weeks
    let (d, today) = makeData(days: 30, doneOn: { _ in 4 })
    let s = Engine.snapshot(d, today: today)
    check(s.counters.perfectWeeks >= 3, "perfect weeks \(s.counters.perfectWeeks)")
    print("ratings after 30 perfect days:", Stat.radarOrder.map { "\($0.name)=\(s.rating($0))" }, "OVR", s.ovr, "level", s.level.level)
    let hist = Engine.ratingHistory(d, stat: .physical, days: 30, today: today)
    check(hist.count == 30, "history count")
    check(hist.last?.rating == s.rating(.physical), "history matches snapshot \(hist.last?.rating ?? -1) vs \(s.rating(.physical))")
    check(Engine.dailyXP(d, days: 7, today: today).reduce(0) { $0 + $1.xp } == 7 * 80, "daily xp")
    let dates = Engine.levelDates(d)
    check(dates[s.level.level] != nil, "level date exists")
}
do {
    // deleted habit stops counting from deletion day
    var (d, today) = makeData(days: 3, doneOn: { _ in 4 })
    d.habits[3].deleted = true
    d.habits[3].updatedAt = Date()
    let s = Engine.snapshot(d, today: today)
    check(s.records[today]?.scheduled == 3, "deleted habit not scheduled today")
    check(s.records[Day.add(-1, to: today)]?.scheduled == 4, "but was yesterday")
}

// MARK: Merge
do {
    var a = AppData()
    var b = AppData()
    let h = Habit(title: "X", stat: .mental, difficulty: .easy, createdDay: Day.today(), updatedAt: Date(timeIntervalSince1970: 100))
    a.habits = [h]
    var h2 = h
    h2.title = "Y"
    h2.updatedAt = Date(timeIntervalSince1970: 200)
    b.habits = [h2, Habit(title: "Z", stat: .social, difficulty: .easy, createdDay: Day.today())]
    let m = a.merged(with: b)
    check(m.habits.count == 2 && m.habits[0].title == "Y", "merge newest wins")
    let enc = try! Store.encoder.encode(m)
    let dec = try! Store.decoder.decode(AppData.self, from: enc)
    check(dec.habits.count == 2, "codable roundtrip")
    // lenient decoding of old files missing fields
    let minimal = #"{"profile":{"name":"Old"}}"#.data(using: .utf8)!
    let old = try! Store.decoder.decode(AppData.self, from: minimal)
    check(old.profile.name == "Old" && old.settings.streakRule == .half && old.habits.isEmpty, "lenient decode")
}

// MARK: AppModel end-to-end
@MainActor func modelTests() {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("dam-test-\(UUID().uuidString)")
    let store = Store(directory: dir)
    let model = AppModel(store: store)
    var events: [FeedbackEvent] = []
    model.feedback = { events.append($0) }
    check(!model.profile.onboarded, "fresh not onboarded")
    check(model.templates.count == 6, "seeded templates")
    model.completeOnboarding(name: "Andy", answers: [.physical: 2, .social: 1], focus: Stat.allCases, intensity: .lockedIn,
                             wakeMinutes: 6 * 60 + 30, theme: .wolf)
    check(model.profile.onboarded && model.profile.name == "Andy", "onboarded")
    let tasks = model.tasks(for: model.today)
    print("Today tasks:", tasks.map { "\($0.title) [\($0.stat.name) \($0.xp)xp]" })
    check(tasks.count == 8, "locked in has 8 tasks got \(tasks.count)")
    check(model.snap.programDay == 1, "program day 1")
    check(model.snap.ovr > 20 && model.snap.ovr < 50, "starting ovr \(model.snap.ovr)")

    for (i, t) in tasks.enumerated() {
        model.toggle(t, day: model.today)
        check(model.tasks(for: model.today)[i].done, "task \(i) done")
    }
    check(events.contains(.taskDone(combo: 1)) && events.contains(.taskDone(combo: 8)), "combo events \(events)")
    check(model.snap.todaySecured && model.snap.streak == 1, "secured, streak 1")
    check(model.celebrations.contains { if case .daySecured = $0 { return true }; return false }, "day secured celebration")
    check(model.celebrations.contains { if case .levelUp = $0 { return true }; return false }, "level up celebration")
    print("After day 1: level \(model.snap.level.level), xp \(model.snap.totalXP), celebrations \(model.celebrations.map(\.id)), toasts \(model.toasts.map(\.title))")
    let xpBefore = model.snap.totalXP
    model.toggle(model.tasks(for: model.today)[0], day: model.today)
    check(model.snap.totalXP < xpBefore, "uncheck removes xp")
    check(events.last == .taskUndone, "undo event")
    model.toggle(model.tasks(for: model.today)[0], day: model.today)
    check(model.snap.totalXP == xpBefore, "recheck restores xp exactly: \(model.snap.totalXP) vs \(xpBefore)")
    let celebCount = model.celebrations.count
    model.toggle(model.tasks(for: model.today)[0], day: model.today)
    model.toggle(model.tasks(for: model.today)[0], day: model.today)
    check(model.celebrations.filter { if case .levelUp = $0 { return true }; return false }.count == model.celebrations.filter { if case .levelUp = $0 { return true }; return false }.count, "noop")
    check(model.celebrations.count <= celebCount + 1, "no duplicate level-up celebrations: \(model.celebrations.map(\.id))")

    // cannot edit 2 days ago
    check(!model.canEdit(Day.add(-2, to: model.today)) && model.canEdit(Day.add(-1, to: model.today)), "edit window")

    // challenges
    let c = model.snap.today
    let ch = Challenges.daily(for: c)[0]
    model.setAccepted(ch.key, accepted: true)
    check(model.tasks(for: c).contains { $0.isChallenge }, "accepted challenge in tasks")
    model.toggleChallenge(ch.key, day: c)
    check(model.isChallengeDone(ch.key, day: c), "challenge done")
    model.setAccepted(ch.key, accepted: false)
    check(!model.isChallengeDone(ch.key, day: c) && !model.isAccepted(ch.key, day: c), "unaccept removes completion")

    // arcs
    model.startArc(Arcs.all[0])
    check(model.activeArcs.count == 1, "arc started")
    model.checkIn(model.activeArcs[0], value: 3.5)
    model.checkIn(model.activeArcs[0], value: 4.1)
    let ap = model.arcProgress(model.activeArcs[0])
    check(ap.checked == 1 && ap.metricTotal == 4.1 && ap.checkedToday && ap.xp > 0, "arc progress \(ap)")
    model.undoCheckIn(model.activeArcs[0])
    check(model.arcProgress(model.activeArcs[0]).checked == 0, "arc undo")

    // tools
    let xp0 = model.snap.totalXP
    model.logFocus(minutes: 25, stat: .intellect, label: "Study")
    check(model.snap.totalXP == xp0 + 25 && model.focusMinutesToday == 25, "focus xp")
    for _ in 0..<4 { model.logBreath(pattern: "Box", seconds: 64) }
    check(model.breathSessionsToday == 4, "breath sessions")
    var j = JournalEntry(kind: .morning, day: model.today, date: Date(), prompts: ["a"], answers: ["grateful"])
    let xp1 = model.snap.totalXP
    model.saveJournal(j)
    j.answers = ["edited"]
    model.saveJournal(j)
    check(model.snap.totalXP == xp1 + 15 && model.journalEntries.count == 1, "journal xp once")
    model.updateSettings { $0.proteinGoal = 100; $0.calorieGoal = 2000; $0.waterGoal = 4 }
    let xp2 = model.snap.totalXP
    model.addMeal(name: "Chicken", calories: 1000, protein: 60)
    model.addMeal(name: "Steak", calories: 900, protein: 50)
    check(model.snap.totalXP == xp2 + 25, "protein + calories xp: \(model.snap.totalXP - xp2)")
    model.addMeal(name: "Cake", calories: 800, protein: 2)
    check(model.snap.totalXP == xp2 + 15, "over calories loses calorie xp: \(model.snap.totalXP - xp2)")
    model.setWater(4)
    check(model.snap.totalXP == xp2 + 25, "water xp")
    check(model.recentMeals.count == 3, "recent meals")

    var w = WorkoutLog(name: "Push", day: model.today, date: Date(), exercises: [
        ExerciseLog(name: "Bench Press", sets: [SetLog(reps: 5, weight: 80, done: true), SetLog(reps: 5, weight: 80, done: true)]),
    ])
    check(model.finishWorkout(w).isEmpty, "first workout no PR")
    var w2 = WorkoutLog(name: "Push", day: model.today, date: Date(), exercises: [
        ExerciseLog(name: "Bench Press", sets: [SetLog(reps: 5, weight: 85, done: true)]),
    ])
    check(model.finishWorkout(w2) == ["Bench Press"], "PR detected")
    w.name = "Push A"
    model.finishWorkout(w)
    check(model.workouts.count == 2, "workout upsert")
    w2.exercises[0].sets[0].weight = 90
    model.deleteWorkout(w2)
    check(model.workouts.count == 1, "workout delete")
    check(model.lastSets(for: "Bench Press")?.count == 2, "last sets")

    model.completeAffirmations()
    model.completeAffirmations()
    check(model.affirmedToday, "affirmed")

    // new program
    model.startNewProgram(intensity: .savage, focus: Stat.allCases)
    check(model.data.program?.number == 2 && model.programHabits.count == 11, "program 2 savage habits \(model.programHabits.count)")

    // custom habit
    var h = model.newHabit()
    h.title = "Floss"
    h.weekdays = [Day.weekday(model.today)]
    model.saveHabit(h)
    check(model.customHabits.count == 1 && model.tasks(for: model.today).contains { $0.title == "Floss" }, "custom habit")

    print("Achievements unlocked:", model.data.unlocks.map(\.id), "toasts:", model.toasts.count)
    print("Final: level \(model.snap.level.level) \(model.snap.rank.name), form \(model.formName), xp \(model.snap.totalXP), OVR \(model.snap.ovr)")

    // persistence
    model.saveNow()
    let reloaded = AppModel(store: store)
    check(reloaded.data.entries.count == model.data.entries.count && reloaded.snap.totalXP == model.snap.totalXP, "reload")
    let exported = try! model.exportData()
    let other = AppModel(store: Store(directory: dir.appendingPathComponent("other")))
    try! other.importData(exported, merge: true)
    check(other.snap.totalXP == model.snap.totalXP, "import merge")
    other.absorb(model.data)
    check(other.snap.totalXP == model.snap.totalXP, "absorb idempotent")
    // focus controller
    let f = FocusController()
    f.setDuration(minutes: 1)
    f.start()
    check(!f.tick(now: Date()), "not finished")
    check(f.tick(now: Date().addingTimeInterval(61)), "finished")
    check(f.phase == .idle, "idle after finish")
    try? FileManager.default.removeItem(at: dir)
}

@MainActor func demoTests() {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("dam-demo-\(UUID().uuidString)")
    let model = AppModel(store: Store(directory: dir))
    model.loadDemo(celebrate: true)
    let s = model.snap
    check(s.programDay == 38, "demo program day \(String(describing: s.programDay))")
    check(s.streak > 3 && s.level.level > 10, "demo progress: streak \(s.streak) level \(s.level.level)")
    check(model.toasts.isEmpty && model.celebrations.count == 1, "demo celebration only")
    check(model.activeArcs.count == 1 && model.arcProgress(model.activeArcs[0]).checked == 11, "demo arc")
    check(model.tasks(for: model.today).filter(\.done).count == 3, "demo today partially done")
    print("Demo: level \(s.level.level) \(s.rank.name), form \(model.formName), OVR \(s.ovr), streak \(s.streak) (best \(s.bestStreak)), xp \(s.totalXP), unlocks \(model.data.unlocks.count)")
    print("Demo ratings:", Stat.radarOrder.map { "\($0.name)=\(s.rating($0))" }.joined(separator: " "))
    try? FileManager.default.removeItem(at: dir)
}

MainActor.assumeIsolated {
    modelTests()
    demoTests()
}

print(failures == 0 ? "ALL TESTS PASSED" : "\(failures) FAILURES")
exit(failures == 0 ? 0 : 1)
