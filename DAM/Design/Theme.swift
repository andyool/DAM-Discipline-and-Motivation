import SwiftUI
import CoreText

enum Theme {
    static let bg = Color(red: 0.016, green: 0.016, blue: 0.024)
    static let card = Color(red: 0.045, green: 0.047, blue: 0.058)
    static let cardRaised = Color(red: 0.075, green: 0.078, blue: 0.094)
    static let stroke = Color.white.opacity(0.09)
    static let text = Color.white
    static let text2 = Color.white.opacity(0.62)
    static let text3 = Color.white.opacity(0.36)
    static let ambient = Color(red: 0.18, green: 0.34, blue: 0.85)
    static let flame = Color(red: 1.0, green: 0.55, blue: 0.15)
    static let maxContentWidth: CGFloat = 720
}

extension Stat {
    var color: Color {
        switch self {
        case .physical: return Color(red: 0.08, green: 0.84, blue: 0.55)
        case .social: return Color(red: 0.16, green: 0.42, blue: 1.0)
        case .discipline: return Color(red: 1.0, green: 0.26, blue: 0.15)
        case .mental: return Color(red: 0.97, green: 0.85, blue: 0.10)
        case .intellect: return Color(red: 1.0, green: 0.51, blue: 0.13)
        case .ambition: return Color(red: 0.54, green: 0.30, blue: 1.0)
        }
    }
}

extension EvolutionTheme {
    var color: Color {
        switch self {
        case .hunter: return Color(red: 0.30, green: 0.58, blue: 1.0)
        case .wolf: return Color(red: 0.62, green: 0.88, blue: 1.0)
        case .warrior: return Color(red: 1.0, green: 0.28, blue: 0.25)
        case .monk: return Color(red: 1.0, green: 0.78, blue: 0.30)
        }
    }
}

extension RankTier {
    var light: Color {
        switch self {
        case .iron: return Color(red: 0.70, green: 0.72, blue: 0.76)
        case .bronze: return Color(red: 0.93, green: 0.62, blue: 0.38)
        case .silver: return Color(red: 0.90, green: 0.93, blue: 0.98)
        case .gold: return Color(red: 1.0, green: 0.86, blue: 0.36)
        case .platinum: return Color(red: 0.55, green: 1.0, blue: 0.90)
        case .diamond: return Color(red: 0.55, green: 0.82, blue: 1.0)
        case .master: return Color(red: 1.0, green: 0.36, blue: 0.36)
        case .ascendant: return Color(red: 1.0, green: 0.94, blue: 0.62)
        case .immortal: return Color(red: 0.80, green: 0.52, blue: 1.0)
        case .legend: return Color(red: 1.0, green: 0.55, blue: 0.92)
        }
    }

    var dark: Color {
        switch self {
        case .iron: return Color(red: 0.22, green: 0.24, blue: 0.27)
        case .bronze: return Color(red: 0.42, green: 0.22, blue: 0.10)
        case .silver: return Color(red: 0.40, green: 0.45, blue: 0.54)
        case .gold: return Color(red: 0.62, green: 0.40, blue: 0.06)
        case .platinum: return Color(red: 0.06, green: 0.42, blue: 0.44)
        case .diamond: return Color(red: 0.10, green: 0.26, blue: 0.72)
        case .master: return Color(red: 0.46, green: 0.03, blue: 0.06)
        case .ascendant: return Color(red: 0.80, green: 0.52, blue: 0.10)
        case .immortal: return Color(red: 0.26, green: 0.08, blue: 0.50)
        case .legend: return Color(red: 0.36, green: 0.08, blue: 0.56)
        }
    }
}

extension Font {
    static func serif(_ size: CGFloat) -> Font { .custom("InstrumentSerif-Regular", size: size) }
    static func serifItalic(_ size: CGFloat) -> Font { .custom("InstrumentSerif-Italic", size: size) }
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font { .system(size: size, weight: weight, design: .monospaced) }
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { .system(size: size, weight: weight) }
}

enum Fonts {
    /// Registers the bundled Instrument Serif fonts (SIL Open Font License).
    static func register() {
        for name in ["InstrumentSerif-Regular", "InstrumentSerif-Italic"] {
            let url = Bundle.main.url(forResource: name, withExtension: "ttf")
                ?? Bundle.main.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts")
            if let url { CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil) }
        }
    }
}
