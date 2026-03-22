import SwiftUI

struct RootView: View {
    @Environment(AppRouter.self) private var router
    @Environment(JellyfinClient.self) private var jellyfinClient

    var body: some View {
        @Bindable var router = router

        Group {
            if jellyfinClient.isAuthenticated {
                mainTabView
            } else {
                ServerConnectionView()
            }
        }
        .animation(.easeInOut, value: jellyfinClient.isAuthenticated)
        .onAppear {
            // Give the router access to the client for player launches
            router.jellyfinClient = jellyfinClient
        }
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
        case .player:
            // Player is handled via UIKit, this shouldn't be reached
            EmptyView()
        case .search:
            SearchView()
        case .settings:
            SettingsView()
        }
    }
}
