import SwiftUI

/// Portrait poster card for a media item.
/// Shows a tall 2:3 ratio poster with focus-driven scale and title reveal.
/// Reports focus state to parent for backdrop changes.
struct MediaCardView: View {

    let item: MediaItemDTO
    var onFocused: (() -> Void)?

    @Environment(JellyfinClient.self) private var jellyfinClient
    @Environment(AppRouter.self) private var router
    @FocusState private var isFocused: Bool

    var body: some View {
        Button {
            router.navigate(to: .mediaDetail(itemId: item.id))
        } label: {
            VStack(spacing: 10) {
                // Portrait poster image
                AsyncPosterImage(
                    url: posterURL,
                    width: Constants.Layout.posterWidth,
                    height: Constants.Layout.posterHeight
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(
                    color: isFocused ? .white.opacity(0.3) : .clear,
                    radius: isFocused ? 12 : 0
                )

                // Title + metadata below poster
                VStack(spacing: 4) {
                    Text(displayTitle)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if isFocused {
                        HStack(spacing: 6) {
                            if let year = item.productionYear {
                                Text(String(year))
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            if let rating = item.communityRating {
                                HStack(spacing: 2) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.yellow)
                                    Text(String(format: "%.1f", rating))
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                            }
                        }
                        .transition(.opacity)
                    }
                }
                .frame(width: Constants.Layout.posterWidth)
            }
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .scaleEffect(isFocused ? 1.08 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
        .onChange(of: isFocused) { _, focused in
            if focused {
                onFocused?()
            }
        }
    }

    // MARK: - Computed Properties

    private var displayTitle: String {
        // For episodes, show the series name (e.g. "Rick and Morty") not "E5 - Meeseeks..."
        if item.type == .episode, let seriesName = item.seriesName {
            return seriesName
        }
        return item.name
    }

    private var posterURL: URL? {
        // For episodes, use the SERIES poster art instead of the episode thumbnail
        if item.type == .episode, let seriesId = item.seriesId {
            return jellyfinClient.imageURL(
                itemId: seriesId,
                imageType: "Primary",
                maxWidth: Constants.Images.posterMaxWidth,
                tag: nil
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
