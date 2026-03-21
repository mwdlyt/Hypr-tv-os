import SwiftUI

struct RootView: View {
    @Environment(AppRouter.self) private var router
    @Environment(JellyfinClient.self) private var jellyfinClient

    var body: some View {
        @Bindable var router = router

        Group {
            if jellyfinClient.isAuthenticated {
                ZStack {
                    // Main tab interface
                    TabView {
                        NavigationStack(path: $router.path) {
                            HomeView()
                                .navigationDestination(for: AppRouter.Destination.self) { destination in
                                    destinationView(for: destination)
                                }
                        }
                        .tabItem {
                            Label("Home", systemImage: "house.fill")
                        }

                        NavigationStack {
                            SearchView()
                        }
                        .tabItem {
                            Label("Search", systemImage: "magnifyingglass")
                        }

                        NavigationStack {
                            SettingsView()
                        }
                        .tabItem {
                            Label("Settings", systemImage: "gearshape.fill")
                        }
                    }

                    // Full-screen player overlay — hides tab bar completely
                    if let playingItemId = router.nowPlayingItemId {
                        PlayerView(itemId: playingItemId)
                            .ignoresSafeArea()
                            .transition(.opacity)
                            .zIndex(100)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: router.nowPlayingItemId)
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
            // Player is now handled as a full-screen overlay — this is a fallback
            PlayerView(itemId: itemId)
        case .search:
            SearchView()
        case .settings:
            SettingsView()
        }
    }
}
