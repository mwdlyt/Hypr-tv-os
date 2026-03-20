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
                // Portrait poster image with progress bar
                ZStack(alignment: .bottom) {
                    AsyncPosterImage(
                        url: posterURL,
                        width: Constants.Layout.posterWidth,
                        height: Constants.Layout.posterHeight
                    )

                    // Progress bar for partially watched items
                    if let progress = watchProgress, progress > 0 && progress < 1 {
                        GeometryReader { geo in
                            VStack {
                                Spacer()
                                ZStack(alignment: .leading) {
                                    // Background track
                                    Rectangle()
                                        .fill(.black.opacity(0.6))
                                        .frame(height: 4)

                                    // Progress fill
                                    Rectangle()
                                        .fill(.blue)
                                        .frame(width: geo.size.width * progress, height: 4)
                                }
                            }
                        }
                    }
                }
                .frame(width: Constants.Layout.posterWidth, height: Constants.Layout.posterHeight)
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
                            // Content rating badge
                            if let officialRating = item.officialRating, !officialRating.isEmpty {
                                Text(officialRating)
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(ratingBadgeColor(for: officialRating), in: RoundedRectangle(cornerRadius: 3))
                            }

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

    /// Returns 0...1 progress for partially watched items, nil if unwatched.
    private var watchProgress: Double? {
        guard let ticks = item.userData?.playbackPositionTicks,
              let totalTicks = item.runTimeTicks,
              totalTicks > 0, ticks > 0 else { return nil }
        return Double(ticks) / Double(totalTicks)
    }

    private var displayTitle: String {
        // For episodes, show the series name (e.g. "Rick and Morty") not "E5 - Meeseeks..."
        if item.type == .episode, let seriesName = item.seriesName {
            return seriesName
        }
        return item.name
    }

    private func ratingBadgeColor(for rating: String) -> Color {
        switch rating {
        case "G", "TV-Y", "TV-Y7", "TV-G":
            return .green.opacity(0.8)
        case "PG", "TV-PG":
            return .blue.opacity(0.8)
        case "PG-13", "TV-14":
            return .orange.opacity(0.8)
        case "R", "TV-MA", "NC-17":
            return .red.opacity(0.8)
        default:
            return .gray.opacity(0.8)
        }
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
