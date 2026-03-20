import Foundation

// MARK: - MediaDetailViewModel

/// Loads full metadata for a single media item and, for series, manages
/// season/episode navigation.
@Observable
final class MediaDetailViewModel {

    // MARK: - Properties

    var item: MediaItemDTO?
    var seasons: [MediaItemDTO] = []
    var episodes: [MediaItemDTO] = []
    var selectedSeason: MediaItemDTO?
    var isLoading: Bool = false
    var error: String?

    /// True when the item has been identified as a series and season data
    /// is still loading.
    var isLoadingEpisodes: Bool = false

    /// True when this item is a series with at least one season.
    var isSeries: Bool {
        item?.type == .series
    }

    // MARK: - Dependencies

    private let itemId: String
    private let client: JellyfinClient

    // MARK: - Init

    init(itemId: String, client: JellyfinClient) {
        self.itemId = itemId
        self.client = client
    }

    // MARK: - Data Loading

    /// Fetches the item's full metadata. For series, also loads the season
    /// list and automatically selects the first season's episodes.
    func loadDetails() async {
        isLoading = true
        error = nil

        do {
            let fetchedItem = try await client.getItem(id: itemId)
            item = fetchedItem

            if fetchedItem.type == .series {
                await loadSeasons(for: fetchedItem.id)
            }
        } catch {
            self.error = "Failed to load details: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Loads episodes for a specific season.
    func loadEpisodes(seasonId: String) async {
        isLoadingEpisodes = true

        do {
            guard let seriesId = item?.id else { return }
            episodes = try await client.getEpisodes(seriesId: seriesId, seasonId: seasonId)
        } catch {
            self.error = "Failed to load episodes: \(error.localizedDescription)"
            episodes = []
        }

        isLoadingEpisodes = false
    }

    /// Selects a season and loads its episodes.
    func selectSeason(_ season: MediaItemDTO) async {
        guard season.id != selectedSeason?.id else { return }
        selectedSeason = season
        await loadEpisodes(seasonId: season.id)
    }

    // MARK: - Private Helpers

    private func loadSeasons(for seriesId: String) async {
        do {
            let fetchedSeasons = try await client.getSeasons(seriesId: seriesId)
            seasons = fetchedSeasons

            // Auto-select the first season that has a "next up" feel:
            // prefer the season the user was last watching (has progress),
            // otherwise fall back to the first season.
            let seasonWithProgress = fetchedSeasons.first { season in
                guard let userData = season.userData else { return false }
                return userData.unplayedItemCount ?? 0 > 0 && userData.playCount > 0
            }

            if let initial = seasonWithProgress ?? fetchedSeasons.first {
                selectedSeason = initial
                await loadEpisodes(seasonId: initial.id)
            }
        } catch {
            self.error = "Failed to load seasons: \(error.localizedDescription)"
        }
    }
}
