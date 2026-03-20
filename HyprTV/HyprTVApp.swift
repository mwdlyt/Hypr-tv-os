import SwiftUI

@main
struct HyprTVApp: App {
    @State private var router = AppRouter()
    @State private var jellyfinClient = JellyfinClient()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .environment(jellyfinClient)
        }
    }
}
