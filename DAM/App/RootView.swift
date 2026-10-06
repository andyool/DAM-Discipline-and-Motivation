import SwiftUI

enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case home, program, progress, challenges, tools, profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .program: return "Program"
        case .progress: return "Progress"
        case .challenges: return "Challenges"
        case .tools: return "Tools"
        case .profile: return "Profile"
        }
    }

    var symbol: String {
        switch self {
        case .home: return "house.fill"
        case .program: return "hexagon.fill"
        case .progress: return "chart.bar.fill"
        case .challenges: return "flame.fill"
        case .tools: return "square.grid.2x2.fill"
        case .profile: return "person.fill"
        }
    }

    /// The iPhone tab bar has room for five; Program lives on Home there.
    static var phoneTabs: [AppTab] { [.home, .progress, .challenges, .tools, .profile] }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(SyncService.self) private var sync
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab: AppTab = LaunchOptions.tab ?? .home
    @State private var didSetup = false

    var body: some View {
        ZStack {
            AppBackground()
            if model.profile.onboarded {
                MainTabs(tab: $tab)
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
            CelebrationLayer()
            ToastLayer()
        }
        .animation(.easeInOut(duration: 0.5), value: model.profile.onboarded)
        .onAppear(perform: setup)
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                model.refreshDay()
                Task {
                    await sync.sync(model)
                    await Reminders.reschedule(model)
                }
            case .background:
                model.saveNow()
                Task { await Reminders.reschedule(model) }
            default:
                break
            }
        }
        .onChange(of: model.settings) { _, settings in
            Feedback.apply(settings: settings)
            Task { await Reminders.reschedule(model) }
        }
        .onChange(of: model.snap.todayRecord.done) { _, _ in
            Task { await Reminders.reschedule(model) }
        }
    }

    private func setup() {
        guard !didSetup else { return }
        didSetup = true
        model.feedback = { Feedback.handle($0) }
        model.onSaved = { [sync, model] in sync.scheduleSync(model) }
        Feedback.apply(settings: model.settings)
        SoundPlayer.shared.preload()
        sync.refresh(model)
        model.startClock()
        model.refreshDay()
    }
}

struct MainTabs: View {
    @Binding var tab: AppTab

    var body: some View {
        #if os(macOS)
        NavigationSplitView {
            List(selection: Binding<AppTab?>(get: { tab }, set: { if let t = $0 { tab = t } })) {
                Section {
                    ForEach(AppTab.allCases) { t in
                        Label(t.title, systemImage: t.symbol).tag(t)
                    }
                } header: {
                    Text("DAM.")
                        .font(.serif(28))
                        .foregroundStyle(.white)
                        .padding(.bottom, 6)
                }
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 210)
        } detail: {
            NavigationStack {
                TabScreen(tab: tab, launchScreen: tab == LaunchOptions.tab ? LaunchOptions.screen : nil)
            }
            .id(tab)
        }
        #else
        TabView(selection: $tab) {
            ForEach(AppTab.phoneTabs) { t in
                NavigationStack {
                    TabScreen(tab: t, launchScreen: t == (LaunchOptions.tab ?? .home) ? LaunchOptions.screen : nil)
                }
                .tabItem { Label(t.title, systemImage: t.symbol) }
                .tag(t)
            }
        }
        #endif
    }
}

struct TabScreen: View {
    let tab: AppTab
    var launchScreen: String? = nil

    @State private var showLaunchScreen = false
    @State private var launched = false

    var body: some View {
        Group {
            switch tab {
            case .home: HomeView()
            case .program: ProgramView()
            case .progress: StatsView()
            case .challenges: ChallengesView()
            case .tools: ToolsView()
            case .profile: ProfileView()
            }
        }
        .background(AppBackground())
        .navigationDestination(isPresented: $showLaunchScreen) {
            LaunchScreenView(name: launchScreen ?? "")
                .background(AppBackground())
        }
        .onAppear {
            if launchScreen != nil && !launched {
                launched = true
                showLaunchScreen = true
            }
        }
    }
}
