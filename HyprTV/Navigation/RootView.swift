import SwiftUI

struct RootView: View {
    @Environment(AppRouter.self) private var router
    @Environment(JellyfinClient.self) private var jellyfinClient

    var body: some View {
        @Bindable var router = router

        Group {
            if jellyfinClient.isAuthenticated {
                ZStack {
                    mainTabView

                    // Thin PlayerView layer handles loading/errors and launches UIKit player
                    if let playingItemId = router.nowPlayingItemId {
                        PlayerView(itemId: playingItemId)
                            .ignoresSafeArea()
                            .zIndex(100)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: router.nowPlayingItemId)
            } else {
                ServerConnectionView()
            }
        }
        .animation(.easeInOut, value: jellyfinClient.isAuthenticated)
    }

    // MARK: - Tab View

    private var mainTabView: some View {
        @Bindable var router = router

        return TabView(selection: Binding(
            get: { router.activeTab },
            set: { router.activeTab = $0 }
        )) {
            NavigationStack(path: $router.path) {
                HomeView()
                    .navigationDestination(for: AppRouter.Destination.self) { destination in
                        destinationView(for: destination)
                    }
            }
            .tabItem { Label("Home", systemImage: "house.fill") }
            .tag(AppRouter.Tab.home)

            NavigationStack(path: $router.searchPath) {
                SearchView()
                    .navigationDestination(for: AppRouter.Destination.self) { destination in
                        destinationView(for: destination)
                    }
            }
            .tabItem { Label("Search", systemImage: "magnifyingglass") }
            .tag(AppRouter.Tab.search)

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gearshape.fill") }
            .tag(AppRouter.Tab.settings)
        }
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
