import SwiftUI

/// Full metadata detail view for a movie, series, or episode.
/// Displays backdrop, metadata, play button, and series-specific content (seasons/episodes).
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
                // MARK: Backdrop
                backdropView(item: item)

                // MARK: Metadata + Actions
                VStack(alignment: .leading, spacing: 32) {
                    // Title and Metadata
                    titleSection(item: item)

                    // Action Buttons
                    actionButtons(item: item)

                    // Overview
                    if let overview = item.overview, !overview.isEmpty {
                        Text(overview)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineLimit(6)
                            .frame(maxWidth: 800, alignment: .leading)
                    }

                    // Genre Tags
                    if let genres = item.genres, !genres.isEmpty {
                        genreTagsView(genres: genres)
                    }

                    // Series: Season Picker + Episodes
                    if item.type == .series {
                        seriesSection(viewModel: viewModel)
                    }

                    // Cast & Crew
                    if let people = item.people, !people.isEmpty {
                        castSection(people: people)
                    }
                }
                .padding(.horizontal, 60)
                .padding(.top, 32)
                .padding(.bottom, 60)
            }
        }
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Backdrop

    private func backdropView(item: MediaItemDTO) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let backdropURL = backdropURL(for: item) {
                AsyncImage(url: backdropURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 600)
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
                colors: [.clear, .black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 300)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: 600)
    }

    private var backdropPlaceholder: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .frame(height: 600)
            .overlay {
                Image(systemName: "photo")
                    .font(.system(size: 60))
                    .foregroundStyle(.tertiary)
            }
    }

    // MARK: - Title Section

    private func titleSection(item: MediaItemDTO) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Series name (for episodes)
            if let seriesName = item.seriesName {
                Text(seriesName)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            // Title
            Text(item.name)
                .font(.title)
                .fontWeight(.bold)

            // Metadata row
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
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
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
    }

    // MARK: - Action Buttons

    private func actionButtons(item: MediaItemDTO) -> some View {
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
        }
    }

    // MARK: - Genre Tags

    private func genreTagsView(genres: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Genres")
                .font(.headline)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(genres, id: \.self) { genre in
                        Text(genre)
                            .font(.callout)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                }
            }
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

    // MARK: - Cast Section

    private func castSection(people: [PersonDTO]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cast & Crew")
                .font(.title3)
                .fontWeight(.semibold)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 20) {
                    ForEach(people, id: \.id) { person in
                        VStack(spacing: 6) {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 80, height: 80)
                                .overlay {
                                    Image(systemName: "person.fill")
                                        .font(.title2)
                                        .foregroundStyle(.tertiary)
                                }

                            Text(person.name)
                                .font(.caption)
                                .fontWeight(.medium)
                                .lineLimit(1)

                            if let role = person.role, !role.isEmpty {
                                Text(role)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .frame(width: 100)
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
}

// MARK: - Preview

#Preview {
    MediaDetailView(itemId: "test-id")
}
