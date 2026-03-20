import SwiftUI

struct RootView: View {
    @Environment(AppRouter.self) private var router
    @Environment(JellyfinClient.self) private var jellyfinClient

    var body: some View {
        @Bindable var router = router

        Group {
            if jellyfinClient.isAuthenticated {
                NavigationStack(path: $router.path) {
                    HomeView()
                        .navigationDestination(for: AppRouter.Destination.self) { destination in
                            switch destination {
                            case .home:
                                HomeView()
                            case .library(let library):
                                LibraryView(library: library)
                            case .mediaDetail(let itemId):
                                MediaDetailView(itemId: itemId)
                            case .player(let itemId):
                                PlayerView(itemId: itemId)
                            case .search:
                                SearchView()
                            case .settings:
                                SettingsView()
                            }
                        }
                }
            } else {
                ServerConnectionView()
            }
        }
        .animation(.easeInOut, value: jellyfinClient.isAuthenticated)
    }
}
