import SwiftUI

/// Full-screen video player container.
/// Hosts the VLC player view controller, transport controls overlay,
/// and Netflix-style Up Next card for episodes.
struct PlayerView: View {

    let itemId: String

    @Environment(JellyfinClient.self) private var jellyfinClient
    @Environment(AppRouter.self) private var router
    @Environment(AudioSettings.self) private var audioSettings
    @State private var viewModel: PlayerViewModel?
    @State private var playerWrapper = VLCPlayerWrapper()
    @State private var currentItem: MediaItemDTO?

    var body: some View {
        ZStack {
            // Video layer
            Color.black
                .ignoresSafeArea()

            if let viewModel {
                // VLC player surface
                PlayerRepresentable(playerWrapper: playerWrapper)
                    .ignoresSafeArea()

                // Transport overlay
                PlayerOverlayView(viewModel: viewModel)
                    .opacity(viewModel.showOverlay ? 1 : 0)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.showOverlay)

                // Up Next overlay (bottom-right corner)
                if viewModel.showUpNext, let nextEp = viewModel.nextEpisode {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            UpNextOverlayView(
                                episode: nextEp,
                                countdown: viewModel.upNextCountdown,
                                onPlayNow: { playNextEpisode() },
                                onDismiss: { viewModel.dismissUpNext() }
                            )
                            .padding(.trailing, 60)
                            .padding(.bottom, 80)
                        }
                    }
                    .animation(.easeInOut(duration: 0.4), value: viewModel.showUpNext)
                }
            } else {
                LoadingView(message: "Preparing playback...")
            }
        }
        .onTapGesture {
            viewModel?.toggleOverlay()
        }
        .task {
            if viewModel == nil {
                let vm = PlayerViewModel(itemId: itemId, client: jellyfinClient)
                viewModel = vm
                do {
                    let streamURL = try await vm.loadPlaybackInfo()
                    playerWrapper.audioSettings = audioSettings
                    playerWrapper.playURL(streamURL)
                    await vm.reportStart()

                    // Load the current item details and pre-fetch next episode
                    if let item = try? await jellyfinClient.getItem(id: itemId) {
                        currentItem = item
                        await vm.loadNextEpisode(currentItem: item)
                    }
                } catch {
                    vm.error = "Failed to load playback info: \(error.localizedDescription)"
                }
            }
        }
        .onDisappear {
            Task {
                await viewModel?.reportStop()
            }
            playerWrapper.stop()
        }
        .onChange(of: viewModel?.currentTime) { _, _ in
            viewModel?.checkUpNextTrigger()

            // Check if playback ended — auto-advance to next
            if let vm = viewModel,
               vm.duration > 0,
               vm.currentTime >= vm.duration - 10_000_000, // within 1 second of end
               vm.shouldAutoPlayNext,
               vm.upNextDismissed || vm.upNextCountdown <= 0 {
                playNextEpisode()
            }
        }
        .navigationBarHidden(true)
        .persistentSystemOverlays(.hidden)
    }

    // MARK: - Next Episode

    private func playNextEpisode() {
        guard let nextEp = viewModel?.nextEpisode else { return }

        // Stop current playback
        Task { await viewModel?.reportStop() }
        playerWrapper.stop()
        viewModel?.resetUpNextState()

        // Navigate to next episode
        router.navigate(to: .player(itemId: nextEp.id))
    }
}

// MARK: - Preview

#Preview {
    PlayerView(itemId: "test-item")
}
