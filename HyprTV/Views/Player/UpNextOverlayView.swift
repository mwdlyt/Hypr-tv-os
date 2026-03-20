import SwiftUI

/// Netflix-style "Up Next" card that appears ~90 seconds before an episode ends.
/// Shows the next episode info with a countdown timer and Play Now / Cancel buttons.
struct UpNextOverlayView: View {

    let episode: MediaItemDTO
    let countdown: Int
    let onPlayNow: () -> Void
    let onDismiss: () -> Void

    @Environment(JellyfinClient.self) private var jellyfinClient

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Card container
            HStack(spacing: 16) {
                // Episode thumbnail
                AsyncPosterImage(
                    url: posterURL,
                    width: 140,
                    height: 80
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Episode info
                VStack(alignment: .leading, spacing: 6) {
                    Text("Up Next")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white.opacity(0.7))
                        .textCase(.uppercase)

                    Text(episodeTitle)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if let overview = episode.overview {
                        Text(overview)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(2)
                    }
                }

                Spacer()
            }
            .padding(20)

            // Action buttons
            HStack(spacing: 12) {
                // Play Now button
                Button(action: onPlayNow) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.caption)
                        Text(countdown > 0 ? "Play Now (\(countdown)s)" : "Playing...")
                            .font(.callout)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(.white, in: Capsule())
                }
                .buttonStyle(.plain)

                // Cancel button
                Button(action: onDismiss) {
                    Text("Cancel")
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(.white.opacity(0.2), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.black.opacity(0.4))
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .frame(maxWidth: 420)
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }

    // MARK: - Computed

    private var episodeTitle: String {
        if let ep = episode.indexNumber {
            let season = episode.parentIndexNumber ?? 1
            return "S\(season):E\(ep) — \(episode.name)"
        }
        return episode.name
    }

    private var posterURL: URL? {
        // Use episode thumbnail if available, otherwise series poster
        let tag = episode.imageTags?["Primary"]
        return jellyfinClient.imageURL(
            itemId: episode.id,
            imageType: "Primary",
            maxWidth: 300,
            tag: tag
        )
    }
}
