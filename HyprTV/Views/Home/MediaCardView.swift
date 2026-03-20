import SwiftUI

/// Premium portrait poster card for a media item.
/// Shows a tall 2:3 ratio poster with focus-driven scale, glow, and title reveal.
struct MediaCardView: View {

    let item: MediaItemDTO

    @Environment(JellyfinClient.self) private var jellyfinClient
    @Environment(AppRouter.self) private var router
    @Environment(\.isFocused) private var isFocused

    var body: some View {
        Button {
            router.navigate(to: .mediaDetail(itemId: item.id))
        } label: {
            posterContent
        }
        .buttonStyle(.card)
        .tvPosterEffect(isFocused: isFocused)
    }

    // MARK: - Poster Content

    private var posterContent: some View {
        VStack(spacing: 8) {
            // Portrait poster
            AsyncPosterImage(
                url: posterURL,
                width: Constants.Layout.posterWidth,
                height: Constants.Layout.posterHeight
            )

            // Title appears only when focused
            if isFocused {
                Text(displayTitle)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .frame(width: Constants.Layout.posterWidth)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }

    // MARK: - Computed Properties

    private var displayTitle: String {
        if item.type == .episode, let ep = item.indexNumber {
            return "E\(ep) - \(item.name)"
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
