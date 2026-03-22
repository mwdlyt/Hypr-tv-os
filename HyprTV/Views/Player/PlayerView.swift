import SwiftUI
import AVKit

/// Full-screen video player using native AVPlayerViewController.
struct PlayerView: View {

    let itemId: String

    @Environment(JellyfinClient.self) private var jellyfinClient
    @Environment(AppRouter.self) private var router
    @Environment(AudioSettings.self) private var audioSettings
    @State private var viewModel: PlayerViewModel?
    @State private var avPlayer = AVPlayerWrapper()
    @State private var currentItem: MediaItemDTO?
    @State private var isLoading = true
    @State private var loadError: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let loadError {
                errorScreen(message: loadError)
            } else if isLoading {
                loadingScreen
            } else {
                playerScreen
            }
        }
        .task {
            await loadAndPlay()
        }
        .onDisappear {
            Task { await viewModel?.reportStop() }
            avPlayer.stop()
        }
        .onChange(of: avPlayer.currentTimeMs) { _, newTime in
            syncPlayerState(timeMs: newTime)
        }
        // Global Menu button handler — always exits the player
        .onExitCommand {
            exitPlayer()
        }
        .navigationBarHidden(true)
        .persistentSystemOverlays(.hidden)
    }

    // MARK: - Error Screen

    private func errorScreen(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.yellow)
            Text("Playback Error")
                .font(.title2)
                .fontWeight(.bold)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 500)
            Button("Go Back") {
                exitPlayer()
            }
            .buttonStyle(.card)
            .padding(.top, 10)
        }
        .focusable() // Ensure this view can receive focus
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Loading Screen

    private var loadingScreen: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Preparing playback...")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .focusable()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Player Screen

    private var playerScreen: some View {
        ZStack {
            AVPlayerRepresentable(
                player: avPlayer.player,
                title: currentItem?.name ?? "",
                subtitle: mediaSubtitle,
                onDismiss: { exitPlayer() }
            )
            .ignoresSafeArea()

            // Skip Intro/Outro button
            if let vm = viewModel, let segment = vm.currentSegment {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        SkipButton(segment: segment) {
                            let seekMs = segment.endTicks / 10_000
                            avPlayer.seek(to: seekMs)
                            vm.seek(to: segment.endTicks)
                        }
                        .padding(.trailing, 60)
                        .padding(.bottom, vm.showUpNext ? 200 : 100)
                    }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: vm.currentSegment?.id)
            }

            // Up Next overlay
            if let vm = viewModel, vm.showUpNext, let nextEp = vm.nextEpisode {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        UpNextOverlayView(
                            episode: nextEp,
                            countdown: vm.upNextCountdown,
                            onPlayNow: { playNextEpisode() },
                            onDismiss: { vm.dismissUpNext() }
                        )
                        .padding(.trailing, 60)
                        .padding(.bottom, 80)
                    }
                }
                .animation(.easeInOut(duration: 0.4), value: vm.showUpNext)
            }
        }
    }

    // MARK: - Helpers

    private var mediaSubtitle: String {
        var parts: [String] = []
        if let year = currentItem?.productionYear { parts.append(String(year)) }
        if let rating = currentItem?.officialRating { parts.append(rating) }
        if let genres = currentItem?.genres, !genres.isEmpty {
            parts.append(genres.prefix(2).joined(separator: ", "))
        }
        return parts.joined(separator: " · ")
    }

    private func exitPlayer() {
        Task { await viewModel?.reportStop() }
        avPlayer.stop()
        router.dismissPlayer()
    }

    private func syncPlayerState(timeMs: Int64) {
        guard let vm = viewModel else { return }
        vm.currentTime = timeMs * 10_000
        vm.duration = avPlayer.durationMs * 10_000
        vm.checkSegmentOverlay()
        vm.checkUpNextTrigger()

        if vm.duration > 0,
           vm.currentTime >= vm.duration - 10_000_000,
           vm.shouldAutoPlayNext,
           vm.upNextDismissed || vm.upNextCountdown <= 0 {
            playNextEpisode()
        }
    }

    private func loadAndPlay() async {
        let vm = PlayerViewModel(itemId: itemId, client: jellyfinClient)
        viewModel = vm

        do {
            if let item = try? await jellyfinClient.getItem(id: itemId) {
                currentItem = item
            }

            let streamURL = try await vm.loadPlaybackInfo()

            avPlayer.mediaTitle = currentItem?.name ?? ""
            avPlayer.mediaSubtitle = mediaSubtitle

            let resumeTicks = currentItem?.userData?.playbackPositionTicks ?? 0
            avPlayer.playURL(streamURL, startPositionTicks: resumeTicks)
            isLoading = false

            await vm.reportStart()
            await vm.loadSegments()

            if let item = currentItem {
                await vm.loadNextEpisode(currentItem: item)
            }
        } catch {
            loadError = error.localizedDescription
            isLoading = false
        }
    }

    private func playNextEpisode() {
        guard let nextEp = viewModel?.nextEpisode else { return }
        exitPlayer()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            router.navigate(to: .player(itemId: nextEp.id))
        }
    }
}
