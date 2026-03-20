import SwiftUI

/// Main home screen displayed after authentication.
/// Shows a tab bar with Home and Search, and horizontal media rows for libraries.
struct HomeView: View {

    @Environment(JellyfinClient.self) private var jellyfinClient
    @Environment(AppRouter.self) private var router
    @State private var viewModel: HomeViewModel?
    @State private var selectedTab: HomeTab = .home

    enum HomeTab: Hashable {
        case home
        case search
        case settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            homeContent
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(HomeTab.home)

            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(HomeTab.search)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .tag(HomeTab.settings)
        }
    }

    // MARK: - Home Content

    @ViewBuilder
    private var homeContent: some View {
        Group {
            if let viewModel {
                if viewModel.isLoading && viewModel.sections.isEmpty {
                    LoadingView(message: "Loading your library...")
                } else if let error = viewModel.error, viewModel.sections.isEmpty {
                    ErrorView(message: error) {
                        Task { await viewModel.refresh() }
                    }
                } else {
                    mediaRows(viewModel: viewModel)
                }
            } else {
                LoadingView()
            }
        }
        .task {
            if viewModel == nil {
                let vm = HomeViewModel(client: jellyfinClient)
                viewModel = vm
                await vm.loadHome()
            }
        }
        .refreshable {
            await viewModel?.refresh()
        }
    }

    // MARK: - Media Rows

    private func mediaRows(viewModel: HomeViewModel) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 40) {
                ForEach(viewModel.sections) { section in
                    MediaRowView(
                        title: section.title,
                        items: section.items,
                        libraryId: section.libraryId
                    )
                }
            }
            .padding(.vertical, 40)
        }
    }
}

// MARK: - Preview

#Preview {
    HomeView()
}
