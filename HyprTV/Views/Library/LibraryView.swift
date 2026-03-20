import SwiftUI

/// Grid view of all items in a media library with sorting controls.
/// Supports infinite scrolling with prefetching — items load before the user reaches the end.
struct LibraryView: View {

    let library: LibraryDTO

    @Environment(JellyfinClient.self) private var jellyfinClient
    @Environment(AppRouter.self) private var router
    @State private var viewModel: LibraryViewModel?

    private let columns = [
        GridItem(.adaptive(minimum: 220, maximum: 260), spacing: 32)
    ]

    var body: some View {
        Group {
            if let viewModel {
                if viewModel.isLoading && viewModel.items.isEmpty {
                    LoadingView(message: "Loading \(library.name)...")
                } else if viewModel.items.isEmpty {
                    emptyState
                } else {
                    gridContent(viewModel: viewModel)
                }
            } else {
                LoadingView()
            }
        }
        .navigationTitle(library.name)
        .task {
            if viewModel == nil {
                let vm = LibraryViewModel(client: jellyfinClient, library: library)
                viewModel = vm
                await vm.loadItems()
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let viewModel {
                    sortMenu(viewModel: viewModel)
                }
            }
        }
    }

    // MARK: - Grid Content

    private func gridContent(viewModel: LibraryViewModel) -> some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 40) {
                ForEach(viewModel.items) { item in
                    MediaCardView(item: item)
                        .onAppear {
                            viewModel.onItemAppear(item)
                        }
                }
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 32)

            // Loading indicator at bottom
            if viewModel.isLoadingMore {
                ProgressView()
                    .padding(.bottom, 40)
            }

            // Item count footer
            if !viewModel.items.isEmpty {
                Text("\(viewModel.items.count) of \(viewModel.totalCount) items")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 20)
            }
        }
    }

    // MARK: - Sort Menu

    private func sortMenu(viewModel: LibraryViewModel) -> some View {
        Menu {
            Section("Sort By") {
                sortButton(viewModel: viewModel, label: "Name", sortBy: "SortName")
                sortButton(viewModel: viewModel, label: "Date Added", sortBy: "DateCreated")
                sortButton(viewModel: viewModel, label: "Release Date", sortBy: "PremiereDate")
                sortButton(viewModel: viewModel, label: "Rating", sortBy: "CommunityRating")
            }

            Section("Order") {
                Button {
                    Task { await viewModel.changeSorting(sortBy: viewModel.sortBy, sortOrder: "Ascending") }
                } label: {
                    Label("Ascending", systemImage: viewModel.sortOrder == "Ascending" ? "checkmark" : "")
                }

                Button {
                    Task { await viewModel.changeSorting(sortBy: viewModel.sortBy, sortOrder: "Descending") }
                } label: {
                    Label("Descending", systemImage: viewModel.sortOrder == "Descending" ? "checkmark" : "")
                }
            }
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
        }
    }

    private func sortButton(viewModel: LibraryViewModel, label: String, sortBy: String) -> some View {
        Button {
            Task { await viewModel.changeSorting(sortBy: sortBy, sortOrder: viewModel.sortOrder) }
        } label: {
            Label(label, systemImage: viewModel.sortBy == sortBy ? "checkmark" : "")
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.on.rectangle.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No items in \(library.name)")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview {
    LibraryView(library: LibraryDTO(
        id: "1", name: "Movies", collectionType: "movies", imageTagsPrimary: nil
    ))
}
