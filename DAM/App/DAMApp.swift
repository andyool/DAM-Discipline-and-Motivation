import SwiftUI

@main
struct DAMApp: App {
    @State private var model = AppModel()
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
