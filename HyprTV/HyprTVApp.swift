import SwiftUI

@main
struct HyprTVApp: App {
    @State private var router = AppRouter()
    @State private var jellyfinClient = JellyfinClient()
    @State private var audioSettings = AudioSettings()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .environment(jellyfinClient)
                .environment(audioSettings)
        }
    }
}
