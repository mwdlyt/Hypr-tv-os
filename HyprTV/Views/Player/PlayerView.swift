import SwiftUI
import AVKit

/// Full-screen video player using native AVPlayerViewController.
/// This gives us:
/// - Native Siri Remote support (swipe to seek, tap to play/pause, menu to exit)
/// - Native transport controls (scrub bar, time display)
/// - Proper tvOS UI conventions
/// Plus our custom overlays: Skip Intro and Up Next.
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
                // Error state
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.yellow)
                    Text("Playback Error")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(loadError)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 500)
                    Button("Go Back") {
                        router.dismissPlayer()
                    }
                    .padding(.top, 20)
                }
            } else if isLoading {
                // Loading state
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Preparing playback...")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            } else {
                // Native AVPlayer view controller
                AVPlayerRepresentable(
                    player: avPlayer.player,
                    title: currentItem?.name ?? "",
                    subtitle: mediaSubtitle,
                    onDismiss: {
                        Task { await viewModel?.reportStop() }
                        avPlayer.stop()
                        router.dismissPlayer()
                    }
                )
                .ignoresSafeArea()

                // Skip Intro/Outro button overlay
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
        .task {
            await loadAndPlay()
        }
        .onDisappear {
            Task { await viewModel?.reportStop() }
            avPlayer.stop()
        }
        .onChange(of: avPlayer.currentTimeMs) { _, newTime in
            // Sync AVPlayer time back to viewModel for Up Next / Skip Intro checks
            if let vm = viewModel {
                vm.currentTime = newTime * 10_000 // convert ms to ticks
                vm.duration = avPlayer.durationMs * 10_000
                vm.checkSegmentOverlay()
                vm.checkUpNextTrigger()

                // Auto-advance at end
                if vm.duration > 0,
                   vm.currentTime >= vm.duration - 10_000_000,
                   vm.shouldAutoPlayNext,
                   vm.upNextDismissed || vm.upNextCountdown <= 0 {
                    playNextEpisode()
                }
            }
        }
        .navigationBarHidden(true)
        .persistentSystemOverlays(.hidden)
    }

    private var mediaSubtitle: String {
        var parts: [String] = []
        if let year = currentItem?.productionYear { parts.append(String(year)) }
        if let rating = currentItem?.officialRating { parts.append(rating) }
        if let genres = currentItem?.genres, !genres.isEmpty {
            parts.append(genres.prefix(2).joined(separator: ", "))
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Load & Play

    private func loadAndPlay() async {
        let vm = PlayerViewModel(itemId: itemId, client: jellyfinClient)
        viewModel = vm

        do {
            // Fetch item details first for metadata
            if let item = try? await jellyfinClient.getItem(id: itemId) {
                currentItem = item
            }

            let streamURL = try await vm.loadPlaybackInfo()

            // Set metadata for native transport bar
            avPlayer.mediaTitle = currentItem?.name ?? ""
            avPlayer.mediaSubtitle = mediaSubtitle

            // Resume from saved position
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

    // MARK: - Next Episode

    private func playNextEpisode() {
        guard let nextEp = viewModel?.nextEpisode else { return }
        Task { await viewModel?.reportStop() }
        avPlayer.stop()
        viewModel?.resetUpNextState()
        router.dismissPlayer()
        // Small delay then launch next
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            router.navigate(to: .player(itemId: nextEp.id))
        }
    }
}
