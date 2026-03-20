import SwiftUI

struct RootView: View {
    @Environment(AppRouter.self) private var router
    @Environment(JellyfinClient.self) private var jellyfinClient

    var body: some View {
        @Bindable var router = router

        Group {
            if jellyfinClient.isAuthenticated {
                TabView {
                    // Home tab
                    NavigationStack(path: $router.path) {
                        HomeView()
                            .navigationDestination(for: AppRouter.Destination.self) { destination in
                                destinationView(for: destination)
                            }
                    }
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }

                    // Search tab
                    NavigationStack {
                        SearchView()
                    }
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }

                    // Settings tab
                    NavigationStack {
                        SettingsView()
                    }
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                }
            } else {
                ServerConnectionView()
            }
        }
        .animation(.easeInOut, value: jellyfinClient.isAuthenticated)
    }

    @ViewBuilder
    private func destinationView(for destination: AppRouter.Destination) -> some View {
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
