import SwiftUI

/// Portrait poster card for a media item.
/// Shows a tall 2:3 ratio poster with focus-driven scale and title reveal.
/// Reports focus state to parent for backdrop changes.
/// Displays watched checkmark and progress bar overlays.
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
            VStack(alignment: .center, spacing: 10) {
                // Portrait poster image with overlays
                ZStack(alignment: .bottom) {
                    ZStack(alignment: .topTrailing) {
                        AsyncPosterImage(
                            url: posterURL,
                            width: Constants.Layout.posterWidth,
                            height: Constants.Layout.posterHeight
                        )

                        // Watched checkmark overlay
                        if item.userData?.played == true {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.6), radius: 4)
                                .padding(8)
                        }
                    }

                    // Progress bar for partially watched items
                    if let progress = watchProgress, progress > 0 && progress < 1 {
                        GeometryReader { geo in
                            VStack {
                                Spacer()
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .fill(.black.opacity(0.6))
                                        .frame(height: 4)
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
                // Focus glow — subtle white border instead of system's big square
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.white.opacity(isFocused ? 0.8 : 0), lineWidth: 2)
                )
                .shadow(
                    color: isFocused ? .white.opacity(0.25) : .clear,
                    radius: isFocused ? 15 : 0
                )

                // Title + metadata below poster — always visible, expands on focus
                VStack(spacing: 4) {
                    Text(displayTitle)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

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

                            if let officialRating = item.officialRating, !officialRating.isEmpty {
                                Text(officialRating)
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.8))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 3))
                            }
                        }
                        .transition(.opacity)
                    }
                }
                .frame(width: Constants.Layout.posterWidth + 20) // slightly wider than poster for text
            }
        }
        // Suppress the default tvOS button focus rectangle
        .buttonStyle(.borderless)
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

    private var watchProgress: Double? {
        guard let ticks = item.userData?.playbackPositionTicks,
              let totalTicks = item.runTimeTicks,
              totalTicks > 0, ticks > 0 else { return nil }
        return Double(ticks) / Double(totalTicks)
    }

    private var displayTitle: String {
        if item.type == .episode, let seriesName = item.seriesName {
            return seriesName
        }
        return item.name
    }

    private var posterURL: URL? {
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
