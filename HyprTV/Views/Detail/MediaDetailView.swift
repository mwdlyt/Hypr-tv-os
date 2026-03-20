import SwiftUI

/// Full metadata detail view for a movie, series, or episode.
/// Premium layout with backdrop, poster+metadata side-by-side, cast, genres,
/// season/episode browser, watch/favorite actions, and similar items.
struct MediaDetailView: View {

    let itemId: String

    @Environment(JellyfinClient.self) private var jellyfinClient
    @Environment(AppRouter.self) private var router
    @State private var viewModel: MediaDetailViewModel?

    var body: some View {
        Group {
            if let viewModel {
                if viewModel.isLoading && viewModel.item == nil {
                    LoadingView(message: "Loading details...")
                } else if let item = viewModel.item {
                    detailContent(item: item, viewModel: viewModel)
                } else {
                    ErrorView(message: "Item not found.") {
                        Task { await viewModel.loadDetails() }
                    }
                }
            } else {
                LoadingView()
            }
        }
        .task {
            if viewModel == nil {
                let vm = MediaDetailViewModel(itemId: itemId, client: jellyfinClient)
                viewModel = vm
                await vm.loadDetails()
            }
        }
    }

    // MARK: - Detail Content

    private func detailContent(item: MediaItemDTO, viewModel: MediaDetailViewModel) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // MARK: Backdrop + Poster/Metadata overlay
                backdropWithMetadata(item: item, viewModel: viewModel)

                // MARK: Below-the-fold content
                VStack(alignment: .leading, spacing: 40) {
                    // Overview
                    if let overview = item.overview, !overview.isEmpty {
                        Text(overview)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineLimit(8)
                            .frame(maxWidth: 900, alignment: .leading)
                    }

                    // Genre Tags
                    if let genres = item.genres, !genres.isEmpty {
                        GenreTagsView(genres: genres)
                    }

                    // Series: Season Picker + Episodes
                    if item.type == .series {
                        seriesSection(viewModel: viewModel)
                    }

                    // Cast & Crew
                    if let people = item.people, !people.isEmpty {
                        CastCrewRow(people: people)
                    }

                    // Studios
                    if let studios = item.studios, !studios.isEmpty {
                        studiosSection(studios: studios)
                    }

                    // Similar Items
                    if !viewModel.similarItems.isEmpty {
                        similarItemsSection(items: viewModel.similarItems)
                    }
                }
                .padding(.horizontal, 60)
                .padding(.top, 40)
                .padding(.bottom, 80)
            }
        }
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Backdrop with Poster & Metadata

    private func backdropWithMetadata(item: MediaItemDTO, viewModel: MediaDetailViewModel) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Background backdrop
            if let backdropURL = backdropURL(for: item) {
                AsyncImage(url: backdropURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 700)
                            .clipped()
                    case .failure, .empty:
                        backdropPlaceholder
                    @unknown default:
                        backdropPlaceholder
                    }
                }
            } else {
                backdropPlaceholder
            }

            // Gradient overlay for readability
            LinearGradient(
                colors: [.clear, .clear, .black.opacity(0.7), .black],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 700)

            // Poster + Metadata side-by-side
            HStack(alignment: .bottom, spacing: 40) {
                // Movie/Show Poster
                posterView(item: item)

                // Metadata column
                VStack(alignment: .leading, spacing: 16) {
                    // Series name (for episodes)
                    if let seriesName = item.seriesName {
                        Text(seriesName)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }

                    // Title
                    Text(item.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    // Metadata badges row
                    metadataRow(item: item)

                    // Action Buttons
                    actionButtons(item: item, viewModel: viewModel)
                }

                Spacer()
            }
            .padding(.horizontal, 60)
            .padding(.bottom, 40)
        }
        .frame(height: 700)
    }

    // MARK: - Poster

    private func posterView(item: MediaItemDTO) -> some View {
        AsyncPosterImage(
            url: posterURL(for: item),
            width: 240,
            height: 360
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
    }

    private var backdropPlaceholder: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .frame(height: 700)
            .overlay {
                Image(systemName: "photo")
                    .font(.system(size: 60))
                    .foregroundStyle(.tertiary)
            }
    }

    // MARK: - Metadata Row

    private func metadataRow(item: MediaItemDTO) -> some View {
        HStack(spacing: 16) {
            if let year = item.productionYear {
                Text(String(year))
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            if let rating = item.communityRating {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                    Text(String(format: "%.1f", rating))
                }
                .font(.headline)
                .foregroundStyle(.secondary)
            }

            if let officialRating = item.officialRating {
                Text(officialRating)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
            }

            if let runtime = TimeFormatter.runtime(from: item.runTimeTicks) {
                Label(runtime, systemImage: "clock")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            // Episode indicator
            if item.type == .episode,
               let season = item.parentIndexNumber,
               let episode = item.indexNumber {
                Text("S\(season) E\(episode)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Action Buttons

    private func actionButtons(item: MediaItemDTO, viewModel: MediaDetailViewModel) -> some View {
        HStack(spacing: 20) {
            // Play Button
            Button {
                router.navigate(to: .player(itemId: item.id))
            } label: {
                Label("Play", systemImage: "play.fill")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.card)

            // Resume if applicable
            if let userData = item.userData, userData.playbackPositionTicks > 0 {
                Button {
                    router.navigate(to: .player(itemId: item.id))
                } label: {
                    let position = TimeFormatter.playerTime(from: TimeFormatter.ticksToSeconds(userData.playbackPositionTicks))
                    Label("Resume from \(position)", systemImage: "play.circle")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.card)
            }

            // Mark Watched / Unwatched
            Button {
                Task { await viewModel.togglePlayed() }
            } label: {
                Label(
                    viewModel.isPlayed ? "Watched" : "Unwatched",
                    systemImage: viewModel.isPlayed ? "checkmark.circle.fill" : "checkmark.circle"
                )
                .font(.headline)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
            .buttonStyle(.card)

            // Favorite
            Button {
                Task { await viewModel.toggleFavorite() }
            } label: {
                Image(systemName: viewModel.isFavorite ? "heart.fill" : "heart")
                    .font(.title3)
                    .foregroundStyle(viewModel.isFavorite ? .red : .white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.card)
        }
    }

    // MARK: - Series Section

    private func seriesSection(viewModel: MediaDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            if !viewModel.seasons.isEmpty {
                SeasonListView(
                    seasons: viewModel.seasons,
                    selectedSeason: viewModel.selectedSeason
                ) { season in
                    Task { await viewModel.selectSeason(season) }
                }
            }

            if !viewModel.episodes.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Episodes")
                        .font(.title3)
                        .fontWeight(.semibold)

                    ForEach(viewModel.episodes) { episode in
                        EpisodeRowView(episode: episode) {
                            router.navigate(to: .player(itemId: episode.id))
                        }
                    }
                }
            } else if viewModel.isLoadingEpisodes {
                ProgressView()
                    .padding(.vertical, 20)
            }
        }
    }

    // MARK: - Studios Section

    private func studiosSection(studios: [StudioDTO]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Studios")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(studios.map(\.name).joined(separator: " \u{2022} "))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Similar Items

    private func similarItemsSection(items: [MediaItemDTO]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("More Like This")
                .font(.title3)
                .fontWeight(.semibold)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Constants.Layout.posterSpacing) {
                    ForEach(items) { similarItem in
                        MediaCardView(item: similarItem)
                    }
                }
                .padding(.vertical, 8)
            }
            .focusSection()
        }
    }

    // MARK: - Helpers

    private func backdropURL(for item: MediaItemDTO) -> URL? {
        if let tags = item.backdropImageTags, let firstTag = tags.first {
            return jellyfinClient.imageURL(
                itemId: item.id,
                imageType: "Backdrop",
                maxWidth: Constants.Images.backdropMaxWidth,
                tag: firstTag
            )
        }
        return nil
    }

    private func posterURL(for item: MediaItemDTO) -> URL? {
        // For episodes, use the series poster
        if item.type == .episode, let seriesId = item.seriesId {
            return jellyfinClient.imageURL(
                itemId: seriesId,
                imageType: "Primary",
                maxWidth: Constants.Images.posterMaxWidth
            )
        }
        let tag = item.imageTags?["Primary"]
        return jellyfinClient.imageURL(
            itemId: item.id,
            imageType: "Primary",
            maxWidth: Constants.Images.posterMaxWidth,
            tag: tag
        )
    }
}

// MARK: - Preview

#Preview {
    MediaDetailView(itemId: "test-id")
}
