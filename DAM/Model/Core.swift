import Foundation

// MARK: - Days

/// Calendar days are stored as "yyyy-MM-dd" keys in the user's local time zone.
/// Internally they are converted to a running day number so day math is pure arithmetic.
enum Day {
    static func today(_ now: Date = Date()) -> String { key(now) }

    static func key(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return key(year: c.year ?? 1970, month: c.month ?? 1, day: c.day ?? 1)
    }

    static func key(year: Int, month: Int, day: Int) -> String {
        "\(pad(year, 4))-\(pad(month, 2))-\(pad(day, 2))"
    }

    static func key(_ number: Int) -> String {
        let (y, m, d) = civil(number)
        return key(year: y, month: m, day: d)
    }

    static func number(_ key: String) -> Int {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return 0 }
        return daysFromCivil(parts[0], parts[1], parts[2])
    }

    static func number(_ date: Date) -> Int { number(key(date)) }

    static func add(_ days: Int, to key: String) -> String { Self.key(number(key) + days) }

    /// Days from `a` to `b` (positive when b is later).
    static func diff(_ a: String, _ b: String) -> Int { number(b) - number(a) }

    /// Local midnight for a day key.
    static func date(_ key: String) -> Date {
        let (y, m, d) = civil(number(key))
        return Calendar.current.date(from: DateComponents(year: y, month: m, day: d)) ?? Date()
    }

    /// Calendar weekday (1 = Sunday ... 7 = Saturday).
    static func weekday(_ key: String) -> Int { weekday(number: number(key)) }

    static func weekday(number: Int) -> Int { (((number + 4) % 7) + 7) % 7 + 1 }

    /// Monday-based index 0...6.
    static func mondayIndex(_ key: String) -> Int { (weekday(key) + 5) % 7 }

    /// Monday of the week containing `key`.
    static func weekStart(_ key: String) -> String { add(-mondayIndex(key), to: key) }

    static func pad(_ value: Int, _ width: Int) -> String {
        let s = String(value)
        return s.count >= width ? s : String(repeating: "0", count: width - s.count) + s
    }

    // Howard Hinnant's civil date algorithms.
    static func daysFromCivil(_ year: Int, _ month: Int, _ day: Int) -> Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let mp = month > 2 ? month - 3 : month + 9
        let doy = (153 * mp + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146097 + doe - 719468
    }

    static func civil(_ number: Int) -> (Int, Int, Int) {
        let z = number + 719468
        let era = (z >= 0 ? z : z - 146096) / 146097
        let doe = z - era * 146097
        let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        let y = yoe + era * 400 + (m <= 2 ? 1 : 0)
        return (y, m, d)
    }

    static let shortWeekdays = ["S", "M", "T", "W", "T", "F", "S"] // indexed by weekday - 1
    static let weekdayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    static let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    /// "Sat, Dec 19."
    static func headline(_ key: String) -> String {
        let (_, m, d) = civil(number(key))
        return "\(weekdayNames[weekday(key) - 1]), \(monthNames[m - 1]) \(d)."
    }

    /// "Dec 19"
    static func short(_ key: String) -> String {
        let (_, m, d) = civil(number(key))
        return "\(monthNames[m - 1]) \(d)"
    }

    /// "Dec 19, 2026"
    static func long(_ key: String) -> String {
        let (y, m, d) = civil(number(key))
        return "\(monthNames[m - 1]) \(d), \(y)"
    }

    /// Minutes after midnight -> "7:45 AM"
    static func clock(_ minutes: Int) -> String {
        let h = (minutes / 60) % 24
        let m = minutes % 60
        let suffix = h < 12 ? "AM" : "PM"
        let h12 = h % 12 == 0 ? 12 : h % 12
        return "\(h12):\(pad(m, 2)) \(suffix)"
    }
}

// MARK: - Stable identifiers

extension UUID {
    /// A deterministic UUID derived from a string, so the same logical record
    /// (e.g. "habit X completed on day Y") gets the same id on every device.
    static func stable(_ name: String) -> UUID {
        var h1: UInt64 = 0xcbf2_9ce4_8422_2325
        var h2: UInt64 = 0x8422_2325_cbf2_9ce4
        for byte in name.utf8 {
            h1 = (h1 ^ UInt64(byte)) &* 0x0000_0100_0000_01b3
            h2 = (h2 ^ UInt64(byte)) &* 0x0000_0100_0000_01b3
            h2 = (h2 << 7) | (h2 >> 57)
        }
        var bytes = [UInt8](repeating: 0, count: 16)
        for i in 0..<8 {
            bytes[i] = UInt8((h1 >> (UInt64(i) * 8)) & 0xff)
            bytes[i + 8] = UInt8((h2 >> (UInt64(i) * 8)) & 0xff)
        }
        bytes[6] = (bytes[6] & 0x0f) | 0x50 // version 5 style
        bytes[8] = (bytes[8] & 0x3f) | 0x80 // RFC 4122 variant
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}

// MARK: - Seeded randomness (stable daily picks)

struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

// MARK: - Roman numerals

func roman(_ n: Int) -> String {
    let table: [(Int, String)] = [(10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")]
    var n = n
    var out = ""
    for (value, symbol) in table {
        while n >= value {
            out += symbol
            n -= value
        }
    }
    return out
}

// MARK: - Lenient decoding

extension KeyedDecodingContainer {
    /// Decodes a value if present and valid, otherwise returns the fallback.
    /// Keeps old save files loading after new fields are added.
    func value<T: Decodable>(_ key: Key, _ fallback: T) -> T {
        ((try? decodeIfPresent(T.self, forKey: key)) ?? nil) ?? fallback
    }
}
