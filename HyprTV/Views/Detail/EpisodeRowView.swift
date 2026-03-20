import SwiftUI

/// Row cell for a single episode showing thumbnail, number, title, overview, and duration.
/// Focusable and tappable to trigger playback.
struct EpisodeRowView: View {

    let episode: MediaItemDTO
    let onPlay: () -> Void

    @Environment(JellyfinClient.self) private var jellyfinClient
    @Environment(\.isFocused) private var isFocused

    private let thumbnailWidth: CGFloat = 260
    private let thumbnailHeight: CGFloat = 146

    var body: some View {
        Button(action: onPlay) {
            HStack(alignment: .top, spacing: 20) {
                // Episode Thumbnail
                thumbnailView

                // Episode Info
                VStack(alignment: .leading, spacing: 6) {
                    // Episode number and title
                    HStack(spacing: 8) {
                        if let ep = episode.indexNumber {
                            Text("E\(ep)")
                                .font(.headline)
                                .foregroundStyle(.blue)
                                .frame(minWidth: 40, alignment: .leading)
                        }

                        Text(episode.name)
                            .font(.headline)
                            .lineLimit(1)
                    }

                    // Duration
                    if let runtime = TimeFormatter.runtime(from: episode.runTimeTicks) {
                        Text(runtime)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Overview snippet
                    if let overview = episode.overview, !overview.isEmpty {
                        Text(overview)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .frame(maxWidth: 500, alignment: .leading)
                    }

                    // Playback progress
                    if let userData = episode.userData, userData.playbackPositionTicks > 0,
                       let ticks = episode.runTimeTicks, ticks > 0 {
                        let progress = Double(userData.playbackPositionTicks) / Double(ticks)
                        ProgressView(value: progress)
                            .tint(.blue)
                            .frame(maxWidth: 300)
                    }
                }

                Spacer()

                // Play indicator
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .opacity(isFocused ? 1 : 0.4)
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.card)
    }

    // MARK: - Thumbnail

    private var thumbnailView: some View {
        AsyncPosterImage(
            url: jellyfinClient.imageURL(
                itemId: episode.id,
                imageType: "Primary",
                maxWidth: Int(thumbnailWidth) * 2,
                tag: episode.imageTags?["Primary"]
            ),
            width: thumbnailWidth,
            height: thumbnailHeight
        )
    }
}

// MARK: - Preview

#Preview {
    EpisodeRowView(
        episode: MediaItemDTO(
            id: "ep1",
            name: "Pilot",
            sortName: nil,
            overview: "The series begins with an exciting first episode.",
            type: .episode,
            seriesName: "Example Show",
            seriesId: nil,
            seasonId: nil,
            indexNumber: 1,
            parentIndexNumber: 1,
            productionYear: 2024,
            communityRating: 8.0,
            officialRating: "TV-14",
            runTimeTicks: 25_000_000_000,
            premiereDate: nil,
            genres: nil,
            studios: nil,
            people: nil,
            mediaSources: nil,
            mediaStreams: nil,
            userData: nil,
            imageTags: nil,
            backdropImageTags: nil
        )
    ) {
        print("Play episode")
    }
}
