import SwiftUI

/// Cinematic hero banner that fills the top ~40% of the screen.
/// Shows a large backdrop image with metadata overlay. The backdrop crossfades
/// when the user moves focus across featured items.
struct HeroBannerView: View {

    let items: [MediaItemDTO]

    @Environment(JellyfinClient.self) private var jellyfinClient
    @Environment(AppRouter.self) private var router
    @State private var selectedIndex: Int = 0
    @State private var backdropImage: UIImage?
    @State private var previousBackdropImage: UIImage?
    @State private var crossfadePhase: Bool = false
    @FocusState private var focusedIndex: Int?

    private var currentItem: MediaItemDTO? {
        guard items.indices.contains(selectedIndex) else { return nil }
        return items[selectedIndex]
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Backdrop layers for crossfade
            backdropLayer

            // Gradient overlay for readability
            LinearGradient(
                colors: [.clear, .black.opacity(0.3), .black.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )

            // Metadata + featured item selector
            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                if let item = currentItem {
                    metadataOverlay(for: item)
                        .padding(.horizontal, Constants.Layout.horizontalPadding)
                        .padding(.bottom, 30)
                }

                // Featured item thumbnails row
                featuredSelector
                    .padding(.bottom, 20)
            }
        }
        .frame(height: Constants.Layout.heroHeight)
        .clipped()
        .onChange(of: selectedIndex) { _, newIndex in
            loadBackdrop(for: newIndex)
        }
        .task {
            loadBackdrop(for: 0)
        }
    }

    // MARK: - Backdrop

    @ViewBuilder
    private var backdropLayer: some View {
        ZStack {
            // Previous image (fades out)
            if let previousBackdropImage {
                Image(uiImage: previousBackdropImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: Constants.Layout.heroHeight)
                    .clipped()
                    .opacity(crossfadePhase ? 0 : 1)
            }

            // Current image (fades in)
            if let backdropImage {
                Image(uiImage: backdropImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: Constants.Layout.heroHeight)
                    .clipped()
                    .opacity(crossfadePhase ? 1 : 0)
            }

            // Fallback when no images loaded yet
            if backdropImage == nil && previousBackdropImage == nil {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        ProgressView()
                    }
            }
        }
        .animation(.easeInOut(duration: Constants.Animation.heroCrossfadeDuration), value: crossfadePhase)
    }

    // MARK: - Metadata Overlay

    private func metadataOverlay(for item: MediaItemDTO) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            Text(item.name)
                .font(.system(size: 52, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .shadow(color: .black.opacity(0.5), radius: 8, y: 4)

            // Metadata pills
            HStack(spacing: 12) {
                if let year = item.productionYear {
                    Text(String(year))
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.9))
                }

                if let rating = item.communityRating {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                        Text(String(format: "%.1f", rating))
                    }
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.9))
                }

                if let officialRating = item.officialRating {
                    Text(officialRating)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 6))
                }

                if let genres = item.genres, !genres.isEmpty {
                    Text(genres.prefix(3).joined(separator: " · "))
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            // Action buttons
            HStack(spacing: 16) {
                Button {
                    router.navigate(to: .player(itemId: item.id))
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                        Text("Play")
                    }
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(.white, in: Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    router.navigate(to: .mediaDetail(itemId: item.id))
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                        Text("More Info")
                    }
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(.white.opacity(0.2), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
        .id(item.id)
        .transition(.opacity.combined(with: .move(edge: .leading)))
        .animation(.easeInOut(duration: 0.3), value: selectedIndex)
    }

    // MARK: - Featured Selector

    private var featuredSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 14) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    featuredThumbnail(item: item, index: index)
                }
            }
            .padding(.horizontal, Constants.Layout.horizontalPadding)
            .padding(.vertical, 8)
        }
        .focusSection()
    }

    private func featuredThumbnail(item: MediaItemDTO, index: Int) -> some View {
        Button {
            router.navigate(to: .mediaDetail(itemId: item.id))
        } label: {
            AsyncPosterImage(
                url: posterURL(for: item),
                width: 120,
                height: 180
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        selectedIndex == index ? .white : .clear,
                        lineWidth: 2
                    )
            )
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .focused($focusedIndex, equals: index)
        .onChange(of: focusedIndex) { _, newFocus in
            if let newFocus {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedIndex = newFocus
                }
            }
        }
        .scaleEffect(selectedIndex == index ? 1.05 : 0.95)
        .opacity(selectedIndex == index ? 1.0 : 0.6)
        .animation(.easeInOut(duration: 0.25), value: selectedIndex)
    }

    // MARK: - Image Loading

    private func posterURL(for item: MediaItemDTO) -> URL? {
        // For episodes, use the series poster instead of episode thumbnail
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

    private func backdropURL(for item: MediaItemDTO) -> URL? {
        let tag = item.backdropImageTags?.first
        let itemId = item.type == .episode ? (item.seriesId ?? item.id) : item.id
        return jellyfinClient.imageURL(
            itemId: itemId,
            imageType: "Backdrop",
            maxWidth: Constants.Images.backdropMaxWidth,
            tag: tag
        )
    }

    private func loadBackdrop(for index: Int) {
        guard items.indices.contains(index),
              let url = backdropURL(for: items[index]) else { return }

        Task {
            // Full-screen hero banner — let the loader keep the server-provided
            // 1920px backdrop instead of downsampling to the poster default.
            let loaded = await ImageLoader.shared.loadImage(from: url, maxPixelSize: 2048)
            guard let loaded else { return }

            await MainActor.run {
                previousBackdropImage = backdropImage
                crossfadePhase = false

                // Small delay to ensure the previous image is rendered before crossfade
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    backdropImage = loaded
                    crossfadePhase = true
                }
            }
        }
    }
}
