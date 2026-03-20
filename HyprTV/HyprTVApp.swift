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
                .task {
                    #if DEBUG
                    // To test with a real server, set these env vars in Xcode scheme:
                    // HYPR_DEBUG_SERVER, HYPR_DEBUG_TOKEN, HYPR_DEBUG_USERID
                    if let server = ProcessInfo.processInfo.environment["HYPR_DEBUG_SERVER"],
                       let token = ProcessInfo.processInfo.environment["HYPR_DEBUG_TOKEN"],
                       let userId = ProcessInfo.processInfo.environment["HYPR_DEBUG_USERID"],
                       !jellyfinClient.isAuthenticated {
                        jellyfinClient.baseURL = URL(string: server)
                        jellyfinClient.accessToken = token
                        jellyfinClient.userId = userId
                    }
                    #endif
                }
        }
    }
}
