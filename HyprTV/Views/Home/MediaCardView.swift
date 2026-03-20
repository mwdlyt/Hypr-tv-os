import SwiftUI

/// Focusable poster card for a media item. Displays the poster image, title, and metadata.
/// Scales up when focused following tvOS conventions.
struct MediaCardView: View {

    let item: MediaItemDTO

    @Environment(JellyfinClient.self) private var jellyfinClient
    @Environment(AppRouter.self) private var router
    @Environment(\.isFocused) private var isFocused

    // MARK: - Layout Constants

    private let posterWidth: CGFloat = 220
    private let posterHeight: CGFloat = 330

    var body: some View {
        Button {
            router.navigate(to: .mediaDetail(itemId: item.id))
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                // Poster Image
                AsyncPosterImage(
                    url: posterURL,
                    width: posterWidth,
                    height: posterHeight
                )

                // Title
                Text(displayTitle)
                    .font(.callout)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .frame(width: posterWidth, alignment: .leading)

                // Subtitle metadata
                subtitleView
                    .frame(width: posterWidth, alignment: .leading)
            }
        }
        .buttonStyle(.card)
        .tvScaleEffect(isFocused: isFocused)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var subtitleView: some View {
        HStack(spacing: 6) {
            if let year = item.productionYear {
                Text(String(year))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let rating = item.communityRating {
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.yellow)
                    Text(String(format: "%.1f", rating))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let officialRating = item.officialRating {
                Text(officialRating)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4))
            }
        }
    }

    // MARK: - Computed Properties

    private var displayTitle: String {
        if item.type == .episode {
            if let ep = item.indexNumber {
                return "E\(ep) - \(item.name)"
            }
        }
        return item.name
    }

    private var posterURL: URL? {
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
    MediaCardView(item: MediaItemDTO(
        id: "1",
        name: "Example Movie",
        sortName: nil,
        overview: nil,
        type: .movie,
        seriesName: nil,
        seriesId: nil,
        seasonId: nil,
        indexNumber: nil,
        parentIndexNumber: nil,
        productionYear: 2024,
        communityRating: 8.5,
        officialRating: "PG-13",
        runTimeTicks: nil,
        premiereDate: nil,
        genres: nil,
        studios: nil,
        people: nil,
        mediaSources: nil,
        mediaStreams: nil,
        userData: nil,
        imageTags: nil,
        backdropImageTags: nil
    ))
}
