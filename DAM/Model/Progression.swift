import Foundation

// MARK: - Levels

enum Leveling {
    /// XP needed to go from `level` to `level + 1`. Early levels come fast, later ones take real consistency.
    static func xpToAdvance(from level: Int) -> Int { 80 + 8 * level }

    /// Total XP required to reach `level`.
    static func totalXP(toReach level: Int) -> Int {
        let n = max(level - 1, 0)
        return 80 * n + 4 * n * (n + 1)
    }

    struct State: Hashable {
        var level: Int
        var into: Int
        var needed: Int
        var total: Int

        var progress: Double { needed > 0 ? Double(into) / Double(needed) : 0 }
        var remaining: Int { max(needed - into, 0) }
    }

    static func state(totalXP: Int) -> State {
        var level = 1
        var remaining = max(totalXP, 0)
        while remaining >= xpToAdvance(from: level) {
            remaining -= xpToAdvance(from: level)
            level += 1
        }
        return State(level: level, into: remaining, needed: xpToAdvance(from: level), total: max(totalXP, 0))
    }
}

// MARK: - Ranks

enum RankTier: Int, CaseIterable, Codable, Hashable {
    case iron, bronze, silver, gold, platinum, diamond, master, ascendant, immortal, legend

    var name: String {
        switch self {
        case .iron: return "Iron"
        case .bronze: return "Bronze"
        case .silver: return "Silver"
        case .gold: return "Gold"
        case .platinum: return "Platinum"
        case .diamond: return "Diamond"
        case .master: return "Master"
        case .ascendant: return "Ascendant"
        case .immortal: return "Immortal"
        case .legend: return "Legend"
        }
    }

    /// Division start levels.
    var divisions: [Int] {
        switch self {
        case .iron: return [1, 3, 5]
        case .bronze: return [7, 10, 13]
        case .silver: return [16, 20, 24]
        case .gold: return [28, 32, 36]
        case .platinum: return [40, 45, 50]
        case .diamond: return [55, 60, 65]
        case .master: return [70, 75, 80]
        case .ascendant: return [85, 90, 95]
        case .immortal: return [100, 108, 116]
        case .legend: return [125]
        }
    }
}

struct Rank: Hashable, Identifiable {
    let tier: RankTier
    /// 1...3, or 0 for single-division tiers.
    let division: Int
    let minLevel: Int
    let maxLevel: Int?

    var id: String { "\(tier.rawValue)-\(division)" }
    var name: String { division == 0 ? tier.name : "\(tier.name) \(roman(division))" }
    var code: String { name.uppercased() }
    var levelRange: String {
        if let maxLevel { return "LVL \(minLevel) - \(maxLevel)" }
        return "LVL \(minLevel)+"
    }
}

enum Ranks {
    static let all: [Rank] = {
        var flat: [(RankTier, Int, Int)] = []
        for tier in RankTier.allCases {
            let starts = tier.divisions
            for (i, start) in starts.enumerated() {
                flat.append((tier, starts.count == 1 ? 0 : i + 1, start))
            }
        }
        return flat.enumerated().map { i, item in
            let next = i + 1 < flat.count ? flat[i + 1].2 - 1 : nil
            return Rank(tier: item.0, division: item.1, minLevel: item.2, maxLevel: next)
        }
    }()

    static func index(forLevel level: Int) -> Int {
        all.lastIndex { $0.minLevel <= level } ?? 0
    }

    static func rank(forLevel level: Int) -> Rank { all[index(forLevel: level)] }

    static func next(after rank: Rank) -> Rank? {
        guard let i = all.firstIndex(of: rank), i + 1 < all.count else { return nil }
        return all[i + 1]
    }

    static func previous(before rank: Rank) -> Rank? {
        guard let i = all.firstIndex(of: rank), i > 0 else { return nil }
        return all[i - 1]
    }
}

// MARK: - Evolution

/// Your avatar evolves through ten forms. The theme decides what you evolve into.
enum EvolutionTheme: String, Codable, CaseIterable, Identifiable, Hashable {
    case hunter, wolf, warrior, monk

    var id: String { rawValue }

    var name: String {
        switch self {
        case .hunter: return "Hunter"
        case .wolf: return "Wolf"
        case .warrior: return "Warrior"
        case .monk: return "Monk"
        }
    }

    var tagline: String {
        switch self {
        case .hunter: return "From unawakened to monarch."
        case .wolf: return "From pup to pack legend."
        case .warrior: return "From recruit to titan."
        case .monk: return "From novice to transcendent."
        }
    }

    var forms: [String] {
        switch self {
        case .hunter:
            return ["Unawakened", "Awakened", "E-Rank Hunter", "D-Rank Hunter", "C-Rank Hunter",
                    "B-Rank Hunter", "A-Rank Hunter", "S-Rank Hunter", "National Hunter", "The Monarch"]
        case .wolf:
            return ["Pup", "Stray", "Hound", "Tracker", "Lone Wolf",
                    "Alpha", "Dire Wolf", "Warg", "Fenrir", "Moonbreaker"]
        case .warrior:
            return ["Recruit", "Squire", "Soldier", "Knight", "Vanguard",
                    "Champion", "Warlord", "Paladin", "Demigod", "Titan"]
        case .monk:
            return ["Novice", "Seeker", "Disciple", "Adept", "Sage",
                    "Master", "Grandmaster", "Enlightened", "Ascended", "Transcendent"]
        }
    }

    /// SF Symbol at the heart of the sigil.
    var emblem: String {
        switch self {
        case .hunter: return "bolt.fill"
        case .wolf: return "pawprint.fill"
        case .warrior: return "shield.lefthalf.filled"
        case .monk: return "flame.fill"
        }
    }
}

enum Evolution {
    /// Level at which each of the ten forms unlocks.
    static let levels = [1, 5, 10, 18, 28, 40, 55, 70, 90, 115]

    static func stage(forLevel level: Int) -> Int {
        levels.lastIndex { $0 <= level } ?? 0
    }

    static func nextStageLevel(after stage: Int) -> Int? {
        stage + 1 < levels.count ? levels[stage + 1] : nil
    }
}

// MARK: - Streak multiplier

enum StreakBonus {
    /// +1.67% XP per streak day, capped at x1.5 after 30 days.
    static func multiplier(streak: Int) -> Double {
        1 + Double(min(max(streak, 0), 30)) / 60
    }

    static func label(_ multiplier: Double) -> String {
        let rounded = (multiplier * 100).rounded() / 100
        var text = String(rounded)
        if text.hasSuffix(".0") { text.removeLast(2) }
        return "x" + text
    }
}
