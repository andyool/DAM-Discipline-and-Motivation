import SwiftUI
import AVFoundation
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Plays the bundled synthesized sound effects.
@MainActor
final class SoundPlayer {
    static let shared = SoundPlayer()

    var enabled = true
    private var players: [String: AVAudioPlayer] = [:]

    private init() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        #endif
    }

    private func url(_ name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "wav")
            ?? Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "Sounds")
    }

    func preload() {
        for name in ["chime1", "chime2", "chime3", "uncheck", "secured", "levelup", "tap"] { _ = player(name) }
    }

    private func player(_ name: String) -> AVAudioPlayer? {
        if let p = players[name] { return p }
        guard let url = url(name), let p = try? AVAudioPlayer(contentsOf: url) else { return nil }
        p.prepareToPlay()
        players[name] = p
        return p
    }

    func play(_ name: String, volume: Float = 1) {
        guard enabled, let p = player(name) else { return }
        p.volume = volume
        p.currentTime = 0
        p.play()
    }
}

enum HapticKind {
    case light, medium, heavy, success, warning, selection
}

@MainActor
enum Haptics {
    static var enabled = true

    static func play(_ kind: HapticKind) {
        guard enabled else { return }
        #if os(iOS)
        switch kind {
        case .light: UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium: UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .heavy: UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .success: UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning: UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .selection: UISelectionFeedbackGenerator().selectionChanged()
        }
        #else
        let pattern: NSHapticFeedbackManager.FeedbackPattern = (kind == .selection || kind == .light) ? .alignment : .levelChange
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
        #endif
    }
}

/// Maps app moments to sound + haptics.
@MainActor
enum Feedback {
    static func apply(settings: Settings) {
        SoundPlayer.shared.enabled = settings.soundOn
        Haptics.enabled = settings.hapticsOn
    }

    static func handle(_ event: FeedbackEvent) {
        switch event {
        case .taskDone(let combo):
            SoundPlayer.shared.play("chime\(min(max(combo, 1), 10))", volume: 0.8)
            Haptics.play(.medium)
        case .taskUndone:
            SoundPlayer.shared.play("uncheck", volume: 0.6)
            Haptics.play(.light)
        case .xpGain:
            SoundPlayer.shared.play("chime5", volume: 0.7)
            Haptics.play(.success)
        case .focusDone:
            SoundPlayer.shared.play("gong")
            Haptics.play(.success)
        }
    }

    static func tap() {
        SoundPlayer.shared.play("tap", volume: 0.5)
        Haptics.play(.selection)
    }

    static func secured() {
        SoundPlayer.shared.play("secured")
        Haptics.play(.success)
    }

    static func levelUp(rankUp: Bool) {
        SoundPlayer.shared.play(rankUp ? "rankup" : "levelup")
        Haptics.play(.heavy)
    }

    static func achievement() {
        SoundPlayer.shared.play("achievement", volume: 0.85)
        Haptics.play(.success)
    }

    static func breath(inhale: Bool) {
        SoundPlayer.shared.play(inhale ? "breath_in" : "breath_out", volume: 0.5)
        Haptics.play(inhale ? .light : .selection)
    }
}
