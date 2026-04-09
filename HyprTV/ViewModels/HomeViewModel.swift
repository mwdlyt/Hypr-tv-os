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
    ///
    /// Concurrency: results are collected into local task-group outputs and
    /// assigned to `self` only after the group completes. This avoids
    /// racing concurrent writes to `latestItemsByLibrary` from background tasks.
    func loadHome() async {
        isLoading = true
        error = nil

        do {
            // Fetch the library list first -- we need it to know which
            // per-library "Latest" rows to request.
            let fetchedLibraries = try await client.getLibraries()
            libraries = fetchedLibraries

            // Fetch resume items and per-library latest items concurrently,
            // then assign results in a single pass once everything finishes.
            // Mutating `self.latestItemsByLibrary` only after all tasks
            // complete prevents concurrent dictionary writes.
            async let resumeFetch: [MediaItemDTO] = fetchResumeItems()

            var byLibrary: [String: [MediaItemDTO]] = [:]
            await withTaskGroup(of: (String, [MediaItemDTO]).self) { group in
                let clientRef = client
                let policy = client.userPolicy
                for library in fetchedLibraries {
                    let libraryId = library.id
                    group.addTask {
                        do {
                            let items = try await clientRef.getLatestItems(parentId: libraryId)
                            return (libraryId, Self.filter(items, policy: policy))
                        } catch {
                            return (libraryId, [])
                        }
                    }
                }
                for await (id, items) in group {
                    byLibrary[id] = items
                }
            }
            latestItemsByLibrary = byLibrary
            resumeItems = await resumeFetch
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

    private func fetchResumeItems() async -> [MediaItemDTO] {
        do {
            let items = try await client.getResumeItems()
            return Self.filter(items, policy: client.userPolicy)
        } catch {
            // Non-fatal: the "Continue Watching" row simply won't appear.
            return []
        }
    }

    /// Filters items client-side based on the user's parental rating policy.
    /// This is a safety layer on top of server-side filtering.
    /// Static so it's safe to call from background tasks in `withTaskGroup`
    /// without touching `self`.
    private static func filter(_ items: [MediaItemDTO], policy: UserPolicy?) -> [MediaItemDTO] {
        guard let policy, policy.maxParentalRating != nil else {
            return items
        }
        return items.filter { policy.isRatingAllowed($0.officialRating) }
    }
}
