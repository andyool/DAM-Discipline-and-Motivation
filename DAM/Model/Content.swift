import Foundation

// MARK: - Daily challenges

struct ChallengeDef: Identifiable, Hashable {
    let key: String
    let name: String
    let detail: String
    let stat: Stat
    let xp: Int
    let symbol: String
    var id: String { key }
}

enum Challenges {
    static let pool: [ChallengeDef] = [
        ChallengeDef(key: "stoic", name: "The Stoic", detail: "Meditate for 10 minutes in complete silence. No music, no app voice, just you.", stat: .mental, xp: 30, symbol: "figure.mind.and.body"),
        ChallengeDef(key: "spartan", name: "The Spartan", detail: "End your shower with 2 minutes of ice-cold water. Breathe through it.", stat: .discipline, xp: 40, symbol: "drop.fill"),
        ChallengeDef(key: "monk", name: "The Monk", detail: "No phone for the first hour after you wake up.", stat: .discipline, xp: 35, symbol: "iphone.slash"),
        ChallengeDef(key: "scholar", name: "The Scholar", detail: "Read 20 pages of a real book.", stat: .intellect, xp: 30, symbol: "book.fill"),
        ChallengeDef(key: "ghost", name: "The Ghost", detail: "Zero social media today. Not one scroll.", stat: .discipline, xp: 45, symbol: "eye.slash.fill"),
        ChallengeDef(key: "warrior", name: "The Warrior", detail: "100 push-ups today. Split them however you want.", stat: .physical, xp: 40, symbol: "figure.strengthtraining.functional"),
        ChallengeDef(key: "wanderer", name: "The Wanderer", detail: "Walk 10,000 steps.", stat: .physical, xp: 30, symbol: "figure.walk"),
        ChallengeDef(key: "ambassador", name: "The Ambassador", detail: "Start a conversation with a stranger and keep it going for 2 minutes.", stat: .social, xp: 45, symbol: "bubble.left.and.bubble.right.fill"),
        ChallengeDef(key: "architect", name: "The Architect", detail: "Write down where you want to be in 5 years, then the 3 moves that get you there.", stat: .ambition, xp: 35, symbol: "building.columns.fill"),
        ChallengeDef(key: "strategist", name: "The Strategist", detail: "Tonight, plan tomorrow hour by hour.", stat: .ambition, xp: 25, symbol: "map.fill"),
        ChallengeDef(key: "craftsman", name: "The Craftsman", detail: "90 minutes of uninterrupted deep work on one thing. Use Lock In.", stat: .ambition, xp: 45, symbol: "hammer.fill"),
        ChallengeDef(key: "sage", name: "The Sage", detail: "Learn one new concept and explain it out loud as if teaching it.", stat: .intellect, xp: 30, symbol: "lightbulb.fill"),
        ChallengeDef(key: "healer", name: "The Healer", detail: "In bed by 10:30 PM, screens off. Get a full 8 hours.", stat: .mental, xp: 30, symbol: "moon.zzz.fill"),
        ChallengeDef(key: "alchemist", name: "The Alchemist", detail: "Zero added sugar and zero junk food today.", stat: .physical, xp: 35, symbol: "leaf.fill"),
        ChallengeDef(key: "hermit", name: "The Hermit", detail: "30 minutes alone with your thoughts. No input: no phone, music or podcasts.", stat: .mental, xp: 35, symbol: "mountain.2.fill"),
        ChallengeDef(key: "gentleman", name: "The Gentleman", detail: "Give 3 genuine compliments to 3 different people.", stat: .social, xp: 30, symbol: "hand.thumbsup.fill"),
        ChallengeDef(key: "loyalist", name: "The Loyalist", detail: "Call (not text) a family member and ask about their life.", stat: .social, xp: 25, symbol: "phone.fill"),
        ChallengeDef(key: "titan", name: "The Titan", detail: "Hold a plank for 3 minutes total today.", stat: .physical, xp: 30, symbol: "figure.core.training"),
        ChallengeDef(key: "sprinter", name: "The Sprinter", detail: "Run 3 km (2 miles). Walk breaks allowed, quitting is not.", stat: .physical, xp: 40, symbol: "figure.run"),
        ChallengeDef(key: "minimalist", name: "The Minimalist", detail: "Declutter one area of your space completely.", stat: .discipline, xp: 25, symbol: "shippingbox.fill"),
        ChallengeDef(key: "riser", name: "The Early Riser", detail: "Be up before 6:30 AM. No snooze.", stat: .discipline, xp: 40, symbol: "sunrise.fill"),
        ChallengeDef(key: "philosopher", name: "The Philosopher", detail: "Journal for 15 minutes about what you actually want from life.", stat: .mental, xp: 30, symbol: "pencil.and.scribble"),
        ChallengeDef(key: "polymath", name: "The Polymath", detail: "30 minutes of an educational lecture, course or documentary.", stat: .intellect, xp: 25, symbol: "graduationcap.fill"),
        ChallengeDef(key: "leader", name: "The Leader", detail: "Help someone today without being asked.", stat: .social, xp: 30, symbol: "figure.2.arms.open"),
        ChallengeDef(key: "hunter", name: "The Hunter", detail: "Do the one task you've been avoiding the longest. Today.", stat: .ambition, xp: 45, symbol: "scope"),
        ChallengeDef(key: "ironmind", name: "The Iron Mind", detail: "No complaining for the entire day. Catch yourself, reset.", stat: .mental, xp: 35, symbol: "brain.head.profile"),
        ChallengeDef(key: "saver", name: "The Saver", detail: "Spend nothing on non-essentials today.", stat: .ambition, xp: 25, symbol: "dollarsign.circle.fill"),
        ChallengeDef(key: "athlete", name: "The Athlete", detail: "20 minutes of stretching and mobility work.", stat: .physical, xp: 25, symbol: "figure.flexibility"),
        ChallengeDef(key: "orator", name: "The Orator", detail: "Record yourself speaking for 2 minutes on any topic. Watch it back.", stat: .social, xp: 35, symbol: "mic.fill"),
        ChallengeDef(key: "faster", name: "The Faster", detail: "16 hours without food. Water, black coffee and tea only.", stat: .discipline, xp: 40, symbol: "fork.knife"),
        ChallengeDef(key: "student", name: "The Student", detail: "Practice a skill you're bad at for 45 minutes.", stat: .intellect, xp: 35, symbol: "brain"),
        ChallengeDef(key: "watchman", name: "The Watchman", detail: "Keep your total screen time under 2 hours.", stat: .discipline, xp: 45, symbol: "hourglass"),
        ChallengeDef(key: "pathfinder", name: "The Pathfinder", detail: "Set 3 concrete goals for this week and write them down.", stat: .ambition, xp: 25, symbol: "flag.checkered"),
        ChallengeDef(key: "calm", name: "The Calm", detail: "Complete 2 breathing sessions in the Breathe tool.", stat: .mental, xp: 25, symbol: "wind"),
        ChallengeDef(key: "host", name: "The Host", detail: "Make real plans with a friend. Date, time, place.", stat: .social, xp: 30, symbol: "person.3.fill"),
        ChallengeDef(key: "chef", name: "The Chef", detail: "Cook a healthy, high-protein meal from scratch.", stat: .physical, xp: 30, symbol: "frying.pan.fill"),
    ]

    static func def(_ key: String) -> ChallengeDef? { pool.first { $0.key == key } }

    /// Three challenges per day, each from a different stat, stable for the whole day.
    static func daily(for day: String) -> [ChallengeDef] {
        var rng = SeededRandom(seed: UInt64(truncatingIfNeeded: Day.number(day)) &* 2654435761)
        var picks: [ChallengeDef] = []
        var usedStats = Set<Stat>()
        for c in pool.shuffled(using: &rng) where !usedStats.contains(c.stat) {
            picks.append(c)
            usedStats.insert(c.stat)
            if picks.count == 3 { break }
        }
        return picks
    }
}

// MARK: - Arcs (multi-day challenges)

struct ArcTemplate: Identifiable, Hashable {
    let id: String
    let name: String
    let tagline: String
    let rule: String
    let days: Int
    let stat: Stat
    let metric: String?
    let symbol: String
    let featuredMonths: [Int]

    var checkInXP: Int { 15 }
    var conquestXP: Int { days * 6 }
}

enum Arcs {
    static let all: [ArcTemplate] = [
        ArcTemplate(id: "winter", name: "Winter Arc", tagline: "While they hibernate, you build.", rule: "Train, read 10 pages, no junk food. Every day. By New Year you're already someone else.", days: 90, stat: .physical, metric: "MILES RAN", symbol: "snowflake", featuredMonths: [10, 11, 12, 1]),
        ArcTemplate(id: "summer", name: "Summer Arc", tagline: "Built in spring. Shown in summer.", rule: "Train daily and hit your protein goal.", days: 90, stat: .physical, metric: "WORKOUTS", symbol: "sun.max.fill", featuredMonths: [3, 4, 5, 6]),
        ArcTemplate(id: "monk", name: "Monk Mode", tagline: "Disappear. Come back different.", rule: "No social media, no junk, at least 2 hours of deep work every day.", days: 30, stat: .discipline, metric: "HOURS FOCUSED", symbol: "figure.mind.and.body", featuredMonths: []),
        ArcTemplate(id: "detox", name: "Dopamine Detox", tagline: "Reset your brain in 7 days.", rule: "No social media, games, porn or junk food for 7 straight days.", days: 7, stat: .mental, metric: nil, symbol: "brain.head.profile", featuredMonths: []),
        ArcTemplate(id: "iron", name: "Iron Arc", tagline: "No days off.", rule: "Train every single day. At least 30 minutes.", days: 30, stat: .physical, metric: "MINUTES TRAINED", symbol: "dumbbell.fill", featuredMonths: []),
        ArcTemplate(id: "scholar", name: "Scholar Arc", tagline: "Readers are leaders.", rule: "Read every day. At least 10 pages.", days: 30, stat: .intellect, metric: "PAGES READ", symbol: "books.vertical.fill", featuredMonths: []),
        ArcTemplate(id: "runner", name: "Road Runner", tagline: "One run a day.", rule: "Run every day, any distance.", days: 30, stat: .physical, metric: "MILES RAN", symbol: "figure.run", featuredMonths: []),
        ArcTemplate(id: "social", name: "Social Arc", tagline: "Confidence is a skill.", rule: "Have a real conversation with someone new every day.", days: 21, stat: .social, metric: "CONVERSATIONS", symbol: "bubble.left.and.bubble.right.fill", featuredMonths: []),
        ArcTemplate(id: "dawn", name: "5 AM Club", tagline: "Own the morning, own the day.", rule: "Out of bed by 5 AM. No snooze.", days: 21, stat: .discipline, metric: nil, symbol: "sunrise.fill", featuredMonths: []),
        ArcTemplate(id: "grind", name: "Grind Season", tagline: "Build something real.", rule: "2+ hours of focused work on your main goal every day.", days: 60, stat: .ambition, metric: "HOURS", symbol: "hammer.fill", featuredMonths: []),
        ArcTemplate(id: "noexcuses", name: "No Excuses", tagline: "Every task. Every day.", rule: "Complete every task on your list, every day, for two weeks.", days: 14, stat: .discipline, metric: nil, symbol: "checkmark.seal.fill", featuredMonths: []),
    ]

    static func template(_ id: String) -> ArcTemplate? { all.first { $0.id == id } }
}

// MARK: - Quotes

struct Quote: Hashable {
    let text: String
    let author: String
}

enum Quotes {
    static let all: [Quote] = [
        Quote(text: "You have power over your mind, not outside events. Realize this, and you will find strength.", author: "Marcus Aurelius"),
        Quote(text: "Waste no more time arguing about what a good man should be. Be one.", author: "Marcus Aurelius"),
        Quote(text: "The impediment to action advances action. What stands in the way becomes the way.", author: "Marcus Aurelius"),
        Quote(text: "At dawn, when you have trouble getting out of bed, tell yourself: I have to go to work as a human being.", author: "Marcus Aurelius"),
        Quote(text: "We suffer more often in imagination than in reality.", author: "Seneca"),
        Quote(text: "Luck is what happens when preparation meets opportunity.", author: "Seneca"),
        Quote(text: "While we are postponing, life speeds by.", author: "Seneca"),
        Quote(text: "No man is free who is not master of himself.", author: "Epictetus"),
        Quote(text: "First say to yourself what you would be; then do what you have to do.", author: "Epictetus"),
        Quote(text: "How long are you going to wait before you demand the best for yourself?", author: "Epictetus"),
        Quote(text: "We are what we repeatedly do. Excellence, then, is not an act, but a habit.", author: "Will Durant"),
        Quote(text: "The journey of a thousand miles begins with a single step.", author: "Lao Tzu"),
        Quote(text: "It does not matter how slowly you go as long as you do not stop.", author: "Confucius"),
        Quote(text: "Today is victory over yourself of yesterday; tomorrow is your victory over lesser men.", author: "Miyamoto Musashi"),
        Quote(text: "There is nothing outside of yourself that can ever enable you to get better, stronger, richer, quicker, or smarter. Everything is within.", author: "Miyamoto Musashi"),
        Quote(text: "Discipline is the bridge between goals and accomplishment.", author: "Jim Rohn"),
        Quote(text: "Motivation is what gets you started. Habit is what keeps you going.", author: "Jim Rohn"),
        Quote(text: "Either you run the day or the day runs you.", author: "Jim Rohn"),
        Quote(text: "Absorb what is useful, discard what is useless and add what is specifically your own.", author: "Bruce Lee"),
        Quote(text: "Do not pray for an easy life, pray for the strength to endure a difficult one.", author: "Bruce Lee"),
        Quote(text: "The successful warrior is the average man, with laser-like focus.", author: "Bruce Lee"),
        Quote(text: "He who has a why to live can bear almost any how.", author: "Friedrich Nietzsche"),
        Quote(text: "Whether you think you can, or you think you can't, you're right.", author: "Henry Ford"),
        Quote(text: "Hard choices, easy life. Easy choices, hard life.", author: "Jerzy Gregorek"),
        Quote(text: "The man who moves a mountain begins by carrying away small stones.", author: "Confucius"),
        Quote(text: "Well done is better than well said.", author: "Benjamin Franklin"),
        Quote(text: "Lost time is never found again.", author: "Benjamin Franklin"),
        Quote(text: "It is not the mountain we conquer, but ourselves.", author: "Edmund Hillary"),
        Quote(text: "The only way to do great work is to love what you do. If you haven't found it yet, keep looking.", author: "Steve Jobs"),
        Quote(text: "Comfort is the enemy of progress.", author: "P. T. Barnum"),
        Quote(text: "A man who conquers himself is greater than one who conquers a thousand men in battle.", author: "Buddha"),
        Quote(text: "What you do every day matters more than what you do once in a while.", author: "Gretchen Rubin"),
        Quote(text: "You do not rise to the level of your goals. You fall to the level of your systems.", author: "James Clear"),
        Quote(text: "Suffer the pain of discipline or suffer the pain of regret.", author: "Jim Rohn"),
        Quote(text: "Don't count the days. Make the days count.", author: "Muhammad Ali"),
        Quote(text: "I hated every minute of training, but I said: don't quit. Suffer now and live the rest of your life as a champion.", author: "Muhammad Ali"),
        Quote(text: "The best time to plant a tree was 20 years ago. The second best time is now.", author: "Proverb"),
        Quote(text: "Fall seven times, stand up eight.", author: "Japanese proverb"),
        Quote(text: "A smooth sea never made a skilled sailor.", author: "Proverb"),
        Quote(text: "Small wins, every day. That's the whole secret.", author: "DAM."),
        Quote(text: "Nobody is coming to save you. Lock in.", author: "DAM."),
        Quote(text: "Your future self is watching. Make him proud.", author: "DAM."),
        Quote(text: "The version of you that you want to be is on the other side of the task you're avoiding.", author: "DAM."),
        Quote(text: "Feelings are visitors. Discipline lives here.", author: "DAM."),
        Quote(text: "You don't need more motivation. You need fewer options.", author: "DAM."),
        Quote(text: "Be so consistent it looks like talent.", author: "DAM."),
        Quote(text: "The streak is the trophy.", author: "DAM."),
        Quote(text: "Do it tired. Do it bored. Do it anyway.", author: "DAM."),
        Quote(text: "Every rep you skip, someone else is doing.", author: "DAM."),
        Quote(text: "Average is a choice. So is greatness.", author: "DAM."),
        Quote(text: "One day or day one. You decide.", author: "Proverb"),
        Quote(text: "Courage is not having the strength to go on; it is going on when you don't have the strength.", author: "Theodore Roosevelt"),
        Quote(text: "Do what you can, with what you have, where you are.", author: "Theodore Roosevelt"),
        Quote(text: "The secret of getting ahead is getting started.", author: "Mark Twain"),
        Quote(text: "Opportunities are usually disguised as hard work, so most people don't recognize them.", author: "Ann Landers"),
        Quote(text: "Strength does not come from winning. Your struggles develop your strengths.", author: "Arnold Schwarzenegger"),
        Quote(text: "The last three or four reps is what makes the muscle grow.", author: "Arnold Schwarzenegger"),
        Quote(text: "If it doesn't challenge you, it doesn't change you.", author: "Fred DeVito"),
        Quote(text: "Act as if what you do makes a difference. It does.", author: "William James"),
        Quote(text: "Knowing is not enough; we must apply. Willing is not enough; we must do.", author: "Goethe"),
    ]

    static func of(day: String) -> Quote {
        let n = Day.number(day)
        return all[((n % all.count) + all.count) % all.count]
    }
}

// MARK: - Affirmations

enum Affirmations {
    static let defaults: [String] = [
        "I do what I said I would do.",
        "I am disciplined when no one is watching.",
        "I don't negotiate with excuses.",
        "My body is strong and getting stronger.",
        "I am becoming the man I want to be, one day at a time.",
        "Discomfort is where I grow.",
        "I am calm under pressure.",
        "I finish what I start.",
        "I deserve the life I'm building.",
        "Every day I choose the hard thing.",
    ]
}

// MARK: - Journal prompts

enum JournalPrompts {
    static func prompts(for kind: JournalKind, day: String) -> [String] {
        switch kind {
        case .morning:
            return ["What am I grateful for this morning?",
                    "What would make today a win?",
                    "What will I do today that my future self will thank me for?"]
        case .evening:
            return ["What did I win today?",
                    "Where did I fall short, and why?",
                    "What will I do better tomorrow?"]
        case .free:
            let n = Day.number(day)
            return [deep[((n % deep.count) + deep.count) % deep.count]]
        }
    }

    static let deep: [String] = [
        "What's on your mind? Get it out of your head and onto the page.",
        "What would you attempt if you knew you couldn't fail?",
        "What habit is quietly holding you back?",
        "Describe the person you'll be one year from now.",
        "What are you avoiding, and what is it costing you?",
        "When did you last feel truly proud of yourself? Why?",
        "What does your ideal day look like, hour by hour?",
        "Who do you need to become to get what you want?",
        "What is one belief about yourself you're ready to drop?",
        "What would the strongest version of you do tomorrow?",
    ]
}

// MARK: - Workouts

enum Exercises {
    static let library: [String] = [
        "Bench Press", "Incline Bench Press", "Incline Dumbbell Press", "Dumbbell Bench Press", "Chest Fly", "Dips", "Push-ups",
        "Overhead Press", "Dumbbell Shoulder Press", "Lateral Raise", "Rear Delt Fly", "Face Pull",
        "Pull-ups", "Chin-ups", "Lat Pulldown", "Barbell Row", "Dumbbell Row", "Seated Cable Row", "Deadlift",
        "Barbell Curl", "Dumbbell Curl", "Hammer Curl", "Tricep Pushdown", "Skull Crushers", "Overhead Tricep Extension",
        "Squat", "Front Squat", "Leg Press", "Romanian Deadlift", "Bulgarian Split Squat", "Lunges",
        "Leg Curl", "Leg Extension", "Hip Thrust", "Calf Raise",
        "Plank", "Hanging Leg Raise", "Cable Crunch", "Ab Wheel",
        "Running", "Cycling", "Rowing", "Jump Rope",
    ]

    static let builtInTemplates: [(String, [String])] = [
        ("Push", ["Bench Press", "Overhead Press", "Incline Dumbbell Press", "Lateral Raise", "Tricep Pushdown"]),
        ("Pull", ["Pull-ups", "Barbell Row", "Lat Pulldown", "Face Pull", "Barbell Curl"]),
        ("Legs", ["Squat", "Romanian Deadlift", "Leg Press", "Leg Curl", "Calf Raise"]),
        ("Upper", ["Bench Press", "Barbell Row", "Overhead Press", "Pull-ups", "Dumbbell Curl", "Tricep Pushdown"]),
        ("Lower", ["Deadlift", "Front Squat", "Bulgarian Split Squat", "Hip Thrust", "Hanging Leg Raise"]),
        ("Full Body", ["Squat", "Bench Press", "Barbell Row", "Overhead Press", "Plank"]),
    ]
}

// MARK: - Onboarding assessment

struct AssessmentQuestion: Hashable {
    let stat: Stat
    let question: String
    let options: [String]
}

enum Assessment {
    static let questions: [AssessmentQuestion] = [
        AssessmentQuestion(stat: .physical, question: "How often do you train?",
                           options: ["Never", "1-2 times a week", "3-4 times a week", "5+ times a week"]),
        AssessmentQuestion(stat: .discipline, question: "What does your screen time look like?",
                           options: ["7+ hours a day", "5-7 hours", "3-5 hours", "Under 3 hours"]),
        AssessmentQuestion(stat: .mental, question: "How do you handle stress?",
                           options: ["It runs my life", "I push it down", "I manage, mostly", "I have a system that works"]),
        AssessmentQuestion(stat: .intellect, question: "How often do you read or learn something new?",
                           options: ["Rarely", "Once a month", "Weekly", "Every day"]),
        AssessmentQuestion(stat: .social, question: "How confident are you around people?",
                           options: ["I avoid people", "Only with close friends", "Fairly confident", "I can talk to anyone"]),
        AssessmentQuestion(stat: .ambition, question: "How clear are your goals?",
                           options: ["No idea what I want", "Vague ideas", "I have some goals", "Written goals and a plan"]),
    ]

    /// Starting rating for an answer index 0...3.
    static func baseline(answer: Int) -> Int { 22 + min(max(answer, 0), 3) * 7 }
}

// MARK: - Program builder

enum ProgramBuilder {
    private static func stages(_ titles: [[String]], _ difficulties: [Difficulty]) -> [HabitStage] {
        Program.phases.enumerated().map { i, phase in
            HabitStage(fromDay: phase.from, titles: titles[min(i, titles.count - 1)], difficulty: difficulties[min(i, difficulties.count - 1)])
        }
    }

    private static func make(_ stat: Stat, _ titles: [[String]], _ difficulties: [Difficulty], program: Program, order: inout Int) -> Habit {
        let st = stages(titles, difficulties)
        order += 1
        return Habit(title: st.first?.titles.first ?? "", stat: stat, difficulty: difficulties.first ?? .medium,
                     stages: st, programID: program.id, createdDay: program.startDay, order: order)
    }

    static let socialRotation: [[String]] = [
        ["Text a friend you haven't talked to in a while", "Give someone a genuine compliment", "Call a family member",
         "Say hi to 3 people you'd normally ignore", "Ask someone about their day and really listen",
         "Thank someone who helped you", "Reply to every message you've been avoiding"],
        ["Start a conversation with a stranger", "Make plans with a friend", "Introduce yourself to someone new",
         "Speak first in a group conversation", "Call a friend instead of texting", "Ask someone for a recommendation",
         "Hold eye contact in every conversation today"],
        ["Talk to a stranger for 2+ minutes", "Invite someone to hang out", "Join or host a social activity",
         "Share an honest opinion in a group", "Reconnect with an old friend", "Help someone without being asked",
         "Go somewhere new and talk to someone there"],
    ]

    static func habits(for program: Program, wakeMinutes: Int) -> [Habit] {
        let focus = Set(program.focus)
        let i = program.intensity
        var order = 0
        var out: [Habit] = []

        func add(_ stat: Stat, _ titles: [[String]], _ diffs: [Difficulty]) {
            guard focus.contains(stat) else { return }
            out.append(make(stat, titles, diffs, program: program, order: &order))
        }

        // Discipline: the wake-up time is the anchor of the day.
        add(.discipline, [["Wake up at \(Day.clock(wakeMinutes))"]], [.medium])

        switch i {
        case .steady:
            add(.physical, [["Work out for 20 min"], ["Work out for 30 min"], ["Work out for 45 min"]], [.medium, .medium, .hard])
            add(.mental, [["Meditate for 5 min"], ["Meditate for 10 min"], ["Meditate for 10 min"]], [.easy, .medium, .medium])
            add(.intellect, [["Read 5 pages"], ["Read 10 pages"], ["Read 15 pages"]], [.easy, .easy, .medium])
            add(.social, socialRotation, [.easy, .medium, .medium])
            add(.ambition, [["Plan tomorrow in 5 minutes"], ["Plan tomorrow and pick 1 priority"], ["30 min of focused work on your goal"]], [.easy, .easy, .medium])
        case .lockedIn:
            add(.physical, [["Work out for 30 min"], ["Work out for 45 min"], ["Work out for 1 hour"]], [.medium, .hard, .hard])
            add(.discipline, [["Less than 4 hours of screen time"], ["Less than 3 hours of screen time"], ["Less than 2.5 hours of screen time"]], [.medium, .medium, .hard])
            add(.mental, [["Meditate for 5 min"], ["Meditate for 10 min"], ["Meditate for 15 min"]], [.easy, .medium, .medium])
            add(.intellect, [["Read 10 pages"], ["Read 20 pages"], ["Read 30 pages"]], [.easy, .medium, .medium])
            add(.social, socialRotation, [.medium, .medium, .hard])
            add(.ambition, [["1 hour of deep work on your goal"], ["90 min of deep work on your goal"], ["2 hours of deep work on your goal"]], [.medium, .hard, .hard])
            add(.physical, [["Drink 2.5L of water"]], [.easy])
        case .savage:
            add(.physical, [["Work out for 45 min"], ["Work out for 1 hour"], ["Work out for 75 min"]], [.hard, .hard, .savage])
            add(.discipline, [["Less than 3 hours of screen time"], ["Less than 2 hours of screen time"], ["Less than 90 min of screen time"]], [.medium, .hard, .savage])
            add(.discipline, [["Cold shower"]], [.hard])
            add(.mental, [["Meditate for 10 min"], ["Meditate for 15 min"], ["Meditate for 20 min"]], [.medium, .medium, .hard])
            add(.intellect, [["Read 20 pages"], ["Read 30 pages"], ["Read 40 pages"]], [.medium, .medium, .hard])
            add(.social, socialRotation, [.medium, .hard, .hard])
            add(.ambition, [["90 min of deep work on your goal"], ["2 hours of deep work on your goal"], ["3 hours of deep work on your goal"]], [.hard, .hard, .savage])
            add(.ambition, [["Plan tomorrow tonight"]], [.easy])
            add(.physical, [["Walk 10,000 steps"], ["Walk 12,000 steps"], ["Walk 15,000 steps"]], [.medium, .medium, .hard])
            add(.physical, [["No junk food or added sugar"]], [.medium])
        }
        return out
    }
}
