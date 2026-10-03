import SwiftUI

/// App entry point. Everything starts here: fonts are registered, the shared AppModel
/// (services + navigation) is created, and RootView decides which screen to show.
@main
struct LoferApp: App {
    @State private var app = AppModel()
    init() { LoferFont.registerBundledFonts() }
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .preferredColorScheme(.dark)
        }
    }
}
