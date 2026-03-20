import SwiftUI

/// Premium home screen with hero spotlight banner and horizontal poster rows.
/// Replaces the old TabView layout with a cinematic, content-first design.
struct HomeView: View {

    @Environment(JellyfinClient.self) private var jellyfinClient
    @Environment(AppRouter.self) private var router
    @State private var viewModel: HomeViewModel?

    var body: some View {
        Group {
            if let viewModel {
                if viewModel.isLoading && viewModel.sections.isEmpty {
                    LoadingView(message: "Loading your library...")
                } else if let error = viewModel.error, viewModel.sections.isEmpty {
                    ErrorView(message: error) {
                        Task { await viewModel.refresh() }
                    }
                } else {
                    mainContent(viewModel: viewModel)
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

    // MARK: - Main Content

    private func mainContent(viewModel: HomeViewModel) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 0) {
                // Hero spotlight banner
                if !viewModel.featuredItems.isEmpty {
                    HeroBannerView(items: viewModel.featuredItems)
                        .padding(.bottom, Constants.Layout.rowSpacing)
                }

                // Content rows
                ForEach(viewModel.sections) { section in
                    MediaRowView(
                        title: section.title,
                        items: section.items,
                        libraryId: section.libraryId
                    )
                    .padding(.bottom, Constants.Layout.rowSpacing)
                }
            }
        }
        .ignoresSafeArea(edges: .top)
    }
}

// MARK: - Preview

#Preview {
    HomeView()
}
