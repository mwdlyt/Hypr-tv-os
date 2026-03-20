import Foundation

// MARK: - HomeViewModel

/// Drives the home screen by aggregating resume-play items and the latest
/// additions from each library into an ordered list of displayable sections.
@Observable
final class HomeViewModel {

    // MARK: - Section Model

    struct Section: Identifiable {
        let id: String
        let title: String
        let items: [MediaItemDTO]
        /// The library this section belongs to, or nil for cross-library sections
        /// such as "Continue Watching".
        let libraryId: String?
    }

    // MARK: - Properties

    var libraries: [LibraryDTO] = []
    var resumeItems: [MediaItemDTO] = []
    var latestItemsByLibrary: [String: [MediaItemDTO]] = [:]
    var isLoading: Bool = false
    var error: String?

    /// Featured items for the hero banner. Picks the first items that have backdrop images.
    var featuredItems: [MediaItemDTO] {
        let allItems = latestItemsByLibrary.values.flatMap { $0 }
        let withBackdrops = allItems.filter { item in
            item.backdropImageTags != nil && !(item.backdropImageTags?.isEmpty ?? true)
        }
        // Fall back to any items if none have backdrops
        let pool = withBackdrops.isEmpty ? Array(allItems) : Array(withBackdrops)
        return Array(pool.prefix(10))
    }

    /// Ordered sections ready for display.
    var sections: [Section] {
        var result: [Section] = []

        if !resumeItems.isEmpty {
            result.append(Section(
                id: "continue-watching",
                title: "Continue Watching",
                items: resumeItems,
                libraryId: nil
            ))
        }

        for library in libraries {
            if let items = latestItemsByLibrary[library.id], !items.isEmpty {
                result.append(Section(
                    id: "latest-\(library.id)",
                    title: "Latest in \(library.name)",
                    items: items,
                    libraryId: library.id
                ))
            }
        }

        return result
    }

    // MARK: - Dependencies

    private let client: JellyfinClient

    // MARK: - Init

    init(client: JellyfinClient) {
        self.client = client
    }

    // MARK: - Data Loading

    /// Fetches all data needed for the home screen: libraries, resume items,
    /// and the latest additions per library. Errors on individual library
    /// fetches are swallowed so the rest of the screen still renders.
    func loadHome() async {
        isLoading = true
        error = nil

        do {
            // Fetch the library list first -- we need it to know which
            // per-library "Latest" rows to request.
            libraries = try await client.getLibraries()

            // Resume items and per-library latest items can be fetched concurrently.
            await withTaskGroup(of: Void.self) { group in
                group.addTask { [self] in
                    await loadResumeItems()
                }

                for library in libraries {
                    group.addTask { [self] in
                        await loadLatestItems(for: library)
                    }
                }
            }
        } catch {
            self.error = "Failed to load home: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Convenience alias that clears stale data and reloads everything.
    func refresh() async {
        libraries = []
        resumeItems = []
        latestItemsByLibrary = [:]
        await loadHome()
    }

    // MARK: - Private Helpers

    private func loadResumeItems() async {
        do {
            let items = try await client.getResumeItems()
            resumeItems = filterByParentalRating(items)
        } catch {
            // Non-fatal: the "Continue Watching" row simply won't appear.
            resumeItems = []
        }
    }

    private func loadLatestItems(for library: LibraryDTO) async {
        do {
            let items = try await client.getLatestItems(parentId: library.id)
            latestItemsByLibrary[library.id] = filterByParentalRating(items)
        } catch {
            // Non-fatal: the section for this library simply won't appear.
            latestItemsByLibrary[library.id] = []
        }
    }

    /// Filters items client-side based on the user's parental rating policy.
    /// This is a safety layer on top of server-side filtering.
    private func filterByParentalRating(_ items: [MediaItemDTO]) -> [MediaItemDTO] {
        guard let policy = client.userPolicy, policy.maxParentalRating != nil else {
            return items
        }
        return items.filter { policy.isRatingAllowed($0.officialRating) }
    }
}
