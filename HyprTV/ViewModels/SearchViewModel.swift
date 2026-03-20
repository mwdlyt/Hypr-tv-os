import Foundation

// MARK: - SearchViewModel

/// Provides debounced, paginated search against the Jellyfin server.
/// The query is automatically dispatched after a 300ms quiet period to avoid
/// flooding the server with requests on every keystroke.
@Observable
final class SearchViewModel {

    // MARK: - Properties

    var query: String = "" {
        didSet {
            guard query != oldValue else { return }
            onQueryChanged()
        }
    }

    var results: [MediaItemDTO] = []
    var isSearching: Bool = false
    var isLoadingMore: Bool = false
    var error: String?
    var totalCount: Int = 0

    var canLoadMore: Bool {
        hasMoreResults && !isSearching && !isLoadingMore
    }

    // MARK: - Dependencies

    private let client: JellyfinClient

    // MARK: - Pagination

    private let pageSize = 50
    private var currentStartIndex: Int = 0
    private var hasMoreResults: Bool = false

    // MARK: - Debounce

    private var debounceTask: Task<Void, Never>?
    private static let debounceInterval: UInt64 = 300_000_000 // 300ms in nanoseconds

    // MARK: - Init

    init(client: JellyfinClient) {
        self.client = client
    }

    // MARK: - Public Methods

    /// Performs an immediate search with the current query, bypassing the
    /// debounce timer. Useful for explicit "Search" button taps.
    func search() async {
        debounceTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            clearResults()
            return
        }

        // Reset pagination for a new search.
        currentStartIndex = 0
        hasMoreResults = false
        isSearching = true
        error = nil

        do {
            let response = try await client.search(query: trimmed, startIndex: 0, limit: pageSize)
            results = response.items
            totalCount = response.totalRecordCount
            currentStartIndex = response.items.count
            hasMoreResults = currentStartIndex < totalCount
        } catch {
            if !Task.isCancelled {
                self.error = "Search failed: \(error.localizedDescription)"
            }
        }

        isSearching = false
    }

    /// Loads the next page of search results.
    func loadMore() async {
        guard canLoadMore else { return }

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isLoadingMore = true

        do {
            let response = try await client.search(query: trimmed, startIndex: currentStartIndex, limit: pageSize)
            results.append(contentsOf: response.items)
            totalCount = response.totalRecordCount
            currentStartIndex += response.items.count
            hasMoreResults = currentStartIndex < totalCount
        } catch {
            if !Task.isCancelled {
                self.error = "Failed to load more results: \(error.localizedDescription)"
            }
        }

        isLoadingMore = false
    }

    /// Called by the view when a result item appears. Triggers pagination
    /// when near the end of the loaded results.
    func onItemAppear(_ item: MediaItemDTO) {
        guard canLoadMore else { return }
        guard let index = results.firstIndex(where: { $0.id == item.id }) else { return }

        let threshold = max(results.count - 10, 0)
        if index >= threshold {
            Task { await loadMore() }
        }
    }

    /// Clears the current results and resets error state.
    func clearResults() {
        results = []
        totalCount = 0
        currentStartIndex = 0
        hasMoreResults = false
        error = nil
    }

    // MARK: - Private Helpers

    /// Called whenever `query` changes. Cancels any pending debounce and
    /// schedules a new search after the debounce interval.
    private func onQueryChanged() {
        debounceTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            clearResults()
            isSearching = false
            return
        }

        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.debounceInterval)
            guard !Task.isCancelled else { return }
            await self?.search()
        }
    }
}
