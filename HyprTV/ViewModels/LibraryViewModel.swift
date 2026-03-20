import Foundation

// MARK: - LibraryViewModel

/// Manages paginated browsing of a single Jellyfin library with sorting, filtering, and genre controls.
///
/// Performance strategy:
/// - Fetches items in pages of 100 using StartIndex + Limit
/// - Prefetches the next page when the user scrolls past 80% of loaded items
/// - Uses diffable identity (MediaItemDTO.id) so SwiftUI only re-renders changed cells
@Observable
final class LibraryViewModel {

    // MARK: - Properties

    var items: [MediaItemDTO] = []
    var isLoading: Bool = false
    var isLoadingMore: Bool = false
    var totalCount: Int = 0
    var error: String?
    var sortBy: String = "SortName"
    var sortOrder: String = "Ascending"

    // MARK: - Filtering

    var availableGenres: [GenreDTO] = []
    var selectedGenreIds: Set<String> = []
    var selectedRatings: Set<String> = []
    var showFilters: Bool = false

    /// Whether any filters are currently active.
    var hasActiveFilters: Bool {
        !selectedGenreIds.isEmpty || !selectedRatings.isEmpty
    }

    /// The library being browsed.
    let library: LibraryDTO

    // MARK: - Pagination

    private let pageSize = 100
    private var currentStartIndex: Int = 0
    private var hasMoreItems: Bool = true
    private var prefetchTask: Task<Void, Never>?

    /// True when there are additional pages available on the server.
    var canLoadMore: Bool {
        hasMoreItems && !isLoading && !isLoadingMore
    }

    // MARK: - Dependencies

    private let client: JellyfinClient

    // MARK: - Init

    init(client: JellyfinClient, library: LibraryDTO) {
        self.client = client
        self.library = library
    }

    // MARK: - Data Loading

    /// Loads the first page of items, resetting any existing state.
    func loadItems() async {
        resetPagination()
        isLoading = true
        error = nil

        do {
            let response = try await client.getItems(
                parentId: library.id,
                startIndex: 0,
                limit: pageSize,
                sortBy: sortBy,
                sortOrder: sortOrder,
                genreIds: genreIdsParam,
                officialRatings: officialRatingsParam
            )

            items = response.items
            totalCount = response.totalRecordCount
            currentStartIndex = response.items.count
            hasMoreItems = currentStartIndex < totalCount
        } catch {
            self.error = "Failed to load library: \(error.localizedDescription)"
        }

        isLoading = false

        // Kick off prefetch of the next page immediately.
        startPrefetchIfNeeded()
    }

    /// Appends the next page of items. Safe to call when `canLoadMore` is true.
    func loadMore() async {
        guard canLoadMore else { return }

        isLoadingMore = true

        do {
            let response = try await client.getItems(
                parentId: library.id,
                startIndex: currentStartIndex,
                limit: pageSize,
                sortBy: sortBy,
                sortOrder: sortOrder,
                genreIds: genreIdsParam,
                officialRatings: officialRatingsParam
            )

            items.append(contentsOf: response.items)
            totalCount = response.totalRecordCount
            currentStartIndex += response.items.count
            hasMoreItems = currentStartIndex < totalCount
        } catch {
            self.error = "Failed to load more items: \(error.localizedDescription)"
        }

        isLoadingMore = false

        // Prefetch the next page in the background.
        startPrefetchIfNeeded()
    }

    /// Called by the view when an item appears on screen.
    /// Triggers pagination when the user is within the last 20% of loaded items.
    func onItemAppear(_ item: MediaItemDTO) {
        guard canLoadMore else { return }

        // Find this item's position in the array.
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }

        // Load more when we're within the last 20% of loaded items.
        let threshold = max(items.count - (pageSize / 5), 0)
        if index >= threshold {
            Task { await loadMore() }
        }
    }

    // MARK: - Sorting

    /// Changes the sort criteria and reloads the library from the first page.
    func changeSorting(sortBy newSortBy: String, sortOrder newSortOrder: String) async {
        sortBy = newSortBy
        sortOrder = newSortOrder
        await loadItems()
    }

    // MARK: - Filtering

    /// Applies filters and reloads items from the first page.
    func applyFilters() async {
        await loadItems()
    }

    /// Clears all active filters and reloads.
    func clearFilters() async {
        selectedGenreIds.removeAll()
        selectedRatings.removeAll()
        await loadItems()
    }

    // MARK: - Genres

    /// Fetches available genres for this library.
    func loadGenres() async {
        do {
            availableGenres = try await client.getGenres(parentId: library.id)
        } catch {
            // Non-fatal
            availableGenres = []
        }
    }

    // MARK: - Alphabet Jump

    /// Reloads items starting with the given letter. Uses NameStartsWith filter.
    func jumpToLetter(_ letter: String) async {
        resetPagination()
        isLoading = true
        error = nil

        let nameStartsWith = letter == "#" ? nil : letter

        do {
            let response = try await client.getItems(
                parentId: library.id,
                startIndex: 0,
                limit: pageSize,
                sortBy: "SortName",
                sortOrder: "Ascending",
                nameStartsWith: nameStartsWith
            )

            items = response.items
            totalCount = response.totalRecordCount
            currentStartIndex = response.items.count
            hasMoreItems = currentStartIndex < totalCount

            // Update sort to match jump context
            sortBy = "SortName"
            sortOrder = "Ascending"
        } catch {
            self.error = "Failed to jump to letter: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Private Helpers

    /// Comma-separated genre IDs for the API, or nil if no genres selected.
    private var genreIdsParam: String? {
        guard !selectedGenreIds.isEmpty else { return nil }
        return selectedGenreIds.joined(separator: ",")
    }

    /// Pipe-separated official ratings for the API, or nil if no ratings selected.
    private var officialRatingsParam: String? {
        guard !selectedRatings.isEmpty else { return nil }
        return selectedRatings.joined(separator: "|")
    }

    private func resetPagination() {
        prefetchTask?.cancel()
        prefetchTask = nil
        items = []
        totalCount = 0
        currentStartIndex = 0
        hasMoreItems = true
    }

    /// Starts a background prefetch of the next page so it's ready when the user scrolls.
    private func startPrefetchIfNeeded() {
        guard hasMoreItems else { return }

        prefetchTask?.cancel()
        prefetchTask = Task { [weak self] in
            guard let self else { return }
            // Small delay so we don't compete with the just-completed fetch.
            try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
            guard !Task.isCancelled else { return }

            // Pre-warm the URLSession connection by fetching (but not appending)
            // the next page. The actual data is discarded — we rely on loadMore()
            // to add it when the user scrolls. This warms HTTP keep-alive and
            // DNS so the real fetch is near-instant.
            do {
                _ = try await self.client.getItems(
                    parentId: self.library.id,
                    startIndex: self.currentStartIndex,
                    limit: 1, // Tiny request just to warm the connection
                    sortBy: self.sortBy,
                    sortOrder: self.sortOrder
                )
            } catch {
                // Prefetch failures are non-fatal.
            }
        }
    }
}
