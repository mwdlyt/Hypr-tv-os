import SwiftUI

/// Home screen with tab bar navigation.
/// The background dynamically changes to the backdrop art of whichever poster
/// the user is currently focused on — applies across ALL rows.
struct HomeView: View {

    @Environment(JellyfinClient.self) private var jellyfinClient
    @Environment(AppRouter.self) private var router
    @State private var viewModel: HomeViewModel?

    /// The currently focused item — drives the background backdrop.
    @State private var focusedItem: MediaItemDTO?
    /// Loaded backdrop UIImage for crossfade.
    @State private var currentBackdrop: UIImage?
    @State private var previousBackdrop: UIImage?
    @State private var showCurrent: Bool = true

    var body: some View {
        Group {
            if let viewModel {
                if viewModel.isLoading && viewModel.sections.isEmpty {
                    LoadingView(message: "Loading your library...")
                } else if let error = viewModel.error, viewModel.sections.isEmpty {
                    ErrorView(message: error) {
                        Task { await viewModel.refresh() }
                    }
                } else {
                    mainContent(viewModel: viewModel)
                }
            } else {
                LoadingView()
            }
        }
        .task {
            if viewModel == nil {
                let vm = HomeViewModel(client: jellyfinClient)
                viewModel = vm
                await vm.loadHome()
            }
        }
        .refreshable {
            await viewModel?.refresh()
        }
        .onChange(of: viewModel?.sections.isEmpty) { _, isEmpty in
            // Load a default backdrop from the first available item on launch
            if isEmpty == false, currentBackdrop == nil {
                if let firstItem = viewModel?.sections.first?.items.first {
                    Task { await loadBackdrop(for: firstItem) }
                }
            }
        }
    }

    // MARK: - Main Content

    private func mainContent(viewModel: HomeViewModel) -> some View {
        ZStack {
            // Dynamic backdrop background
            backdropBackground
                .ignoresSafeArea()

            // Content overlay
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: Constants.Layout.rowSpacing) {
                    // Content rows — each row reports focus back to us
                    ForEach(viewModel.sections) { section in
                        MediaRowView(
                            title: section.title,
                            items: section.items,
                            libraryId: section.libraryId,
                            onItemFocused: { item in
                                handleFocusChange(item)
                            }
                        )
                    }
                }
                .padding(.top, 20)
            }
        }
    }

    // MARK: - Dynamic Backdrop

    @ViewBuilder
    private var backdropBackground: some View {
        ZStack {
            // Base dark color
            Color.black

            // Previous backdrop (fades out)
            if let previousBackdrop {
                Image(uiImage: previousBackdrop)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .opacity(showCurrent ? 0 : 0.4)
            }

            // Current backdrop (fades in)
            if let currentBackdrop {
                Image(uiImage: currentBackdrop)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .opacity(showCurrent ? 0.4 : 0)
            }

            // Dark gradient overlay so text/posters remain readable
            LinearGradient(
                colors: [
                    .black.opacity(0.5),
                    .black.opacity(0.7),
                    .black.opacity(0.85)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .animation(.easeInOut(duration: 0.5), value: showCurrent)
    }

    /// Debounce task — cancelled on every focus change so only the last one fires.
    @State private var backdropDebounceTask: Task<Void, Never>?

    // MARK: - Focus Handling

    private func handleFocusChange(_ item: MediaItemDTO?) {
        guard let item, item.id != focusedItem?.id else { return }
        focusedItem = item

        // Cancel any pending backdrop load — only load after user settles on an item
        backdropDebounceTask?.cancel()
        backdropDebounceTask = Task {
            // Wait 300ms — if user is still scrolling, this task gets cancelled
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await loadBackdrop(for: item)
        }
    }

    private func loadBackdrop(for item: MediaItemDTO) async {
        // Build backdrop URL — fall back to series backdrop for episodes
        let itemId = item.type == .episode ? (item.seriesId ?? item.id) : item.id
        let tag = item.backdropImageTags?.first

        // Use a lower resolution for backdrops — 960px is enough for a blurred background
        guard let url = jellyfinClient.imageURL(
            itemId: itemId,
            imageType: "Backdrop",
            maxWidth: 960,
            tag: tag
        ) else { return }

        // Backdrops need to fill a 1080p+ display — let the loader keep the
        // full 960px server response rather than downsampling to the poster default.
        guard let loaded = await ImageLoader.shared.loadImage(from: url, maxPixelSize: 1024) else { return }
        guard !Task.isCancelled else { return }

        await MainActor.run {
            guard !Task.isCancelled else { return }
            previousBackdrop = currentBackdrop
            showCurrent = false

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                currentBackdrop = loaded
                showCurrent = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    HomeView()
}
