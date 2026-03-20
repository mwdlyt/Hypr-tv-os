import SwiftUI

/// Search screen with a text field and paginated results grid.
/// The SearchViewModel handles 300ms debounce internally — no duplicate debounce here.
struct SearchView: View {

    @Environment(JellyfinClient.self) private var jellyfinClient
    @Environment(AppRouter.self) private var router
    @State private var viewModel: SearchViewModel?

    private let columns = [
        GridItem(.adaptive(minimum: 220, maximum: 260), spacing: 32)
    ]

    var body: some View {
        Group {
            if let viewModel {
                searchContent(viewModel: viewModel)
            } else {
                LoadingView()
            }
        }
        .task {
            if viewModel == nil {
                viewModel = SearchViewModel(client: jellyfinClient)
            }
        }
        .navigationTitle("Search")
    }

    // MARK: - Search Content

    @ViewBuilder
    private func searchContent(viewModel: SearchViewModel) -> some View {
        @Bindable var vm = viewModel

        VStack(spacing: 0) {
            // Search Field
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                TextField("Search movies, shows, and more...", text: $vm.query)
                    .font(.title3)
                    .autocorrectionDisabled()
                    .onSubmit {
                        Task { await viewModel.search() }
                    }

                if !viewModel.query.isEmpty {
                    Button {
                        vm.query = ""
                        viewModel.clearResults()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 60)
            .padding(.top, 20)
            .padding(.bottom, 32)

            // Results
            if viewModel.isSearching && viewModel.results.isEmpty {
                LoadingView(message: "Searching...")
            } else if viewModel.query.isEmpty {
                emptyQueryState
            } else if viewModel.results.isEmpty && !viewModel.isSearching {
                noResultsState
            } else {
                resultsGrid(viewModel: viewModel)
            }
        }
    }

    // MARK: - Results Grid

    private func resultsGrid(viewModel: SearchViewModel) -> some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 40) {
                ForEach(viewModel.results) { item in
                    MediaCardView(item: item)
                        .onAppear {
                            viewModel.onItemAppear(item)
                        }
                }
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 20)

            // Loading more indicator
            if viewModel.isLoadingMore {
                ProgressView()
                    .padding(.bottom, 20)
            }

            // Result count
            if !viewModel.results.isEmpty {
                Text("\(viewModel.results.count) of \(viewModel.totalCount) results")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 20)
            }
        }
    }

    // MARK: - Empty States

    private var emptyQueryState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)

            Text("Start typing to search")
                .font(.title3)
                .foregroundStyle(.secondary)

            Text("Find movies, TV shows, and episodes across your libraries")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noResultsState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)

            Text("No Results")
                .font(.title3)
                .fontWeight(.semibold)

            if let viewModel {
                Text("No results found for \"\(viewModel.query)\"")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview {
    SearchView()
}
