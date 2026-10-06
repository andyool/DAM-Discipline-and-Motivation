import SwiftUI

@main
struct DAMApp: App {
    @State private var model = LaunchOptions.makeModel()
    @State private var sync = SyncService()

    init() {
        Fonts.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(sync)
                .preferredColorScheme(.dark)
                .tint(.white)
        }
        #if os(macOS)
        .defaultSize(width: 1120, height: 800)
        .windowResizability(.contentMinSize)
        #endif
    }
}

/// Launch arguments, mainly for screenshots and test drives:
/// `-demoData YES` (sample history, never touches your real data), `-tab progress`,
/// `-screen ranks`, `-celebrate YES`.
@MainActor
enum LaunchOptions {
    static var demo: Bool { UserDefaults.standard.bool(forKey: "demoData") }
    static var celebrate: Bool { UserDefaults.standard.bool(forKey: "celebrate") }
    static var tab: AppTab? { UserDefaults.standard.string(forKey: "tab").flatMap(AppTab.init(rawValue:)) }
    static var screen: String? { UserDefaults.standard.string(forKey: "screen") }

    static func makeModel() -> AppModel {
        guard demo else { return AppModel() }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("DAM-demo-\(UUID().uuidString)", isDirectory: true)
        let model = AppModel(store: Store(directory: dir))
        model.loadDemo(celebrate: celebrate)
        return model
    }
}

/// Screens that can be opened directly with `-screen <name>`.
struct LaunchScreenView: View {
    let name: String

    var body: some View {
        switch name {
        case "program": ProgramView()
        case "ranks": RankLadderView()
        case "achievements": AchievementsView()
        case "evolution": EvolutionView()
        case "focus": FocusView()
        case "breathe": BreatheView()
        case "journal": JournalView()
        case "lift": WorkoutsView()
        case "fuel": NutritionView()
        case "coach": CoachView()
        case "mirror": MirrorView()
        case "settings": SettingsView()
        case "stat": StatDetailView(stat: .physical)
        default: Text("Unknown screen \(name)")
        }
    }
}
