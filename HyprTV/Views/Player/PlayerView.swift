import SwiftUI

/// Main player view combining VLC video rendering with custom overlay controls.
/// Handles Siri Remote input for play/pause, overlay toggle, seeking, and dismissal.
struct PlayerView: View {

    let itemId: String
    var currentItem: MediaItemDTO?

    @Environment(JellyfinClient.self) private var jellyfinClient
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: PlayerViewModel?
    @State private var vlcWrapper = VLCPlayerWrapper()
    @State private var overlayVisible = true
    @State private var hideTask: Task<Void, Never>?
    @State private var progressReportTask: Task<Void, Never>?
    @State private var hasStarted = false

    var body: some View {
        ZStack {
            // VLC video layer
            PlayerRepresentable(playerWrapper: vlcWrapper)
                .ignoresSafeArea()

            // Buffering spinner (centered, shown when overlay is hidden)
            if vlcWrapper.isBuffering && !overlayVisible {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            }

            // Transport overlay
            if overlayVisible, let vm = viewModel {
                PlayerOverlayView(
                    viewModel: vm,
                    vlcWrapper: vlcWrapper,
                    currentItem: currentItem,
                    onExternalSubtitleLoaded: { url in
                        vlcWrapper.loadExternalSubtitle(url: url)
                    }
                )
                .transition(.opacity.animation(.easeInOut(duration: 0.25)))
            }

            // Skip button (intro/outro/recap)
            if let vm = viewModel, let segment = vm.currentSegment, !overlayVisible {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        SkipButton(segment: segment) {
                            let targetMs = segment.endTicks / 10_000 // ticks → ms
                            vlcWrapper.seek(to: targetMs)
                        }
                        .padding(.trailing, 60)
                        .padding(.bottom, 80)
                    }
                }
                .transition(.opacity)
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
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .persistentSystemOverlays(.hidden)
        .onAppear { startPlayback() }
        .onDisappear { stopPlayback() }
        .onPlayPauseCommand { handlePlayPause() }
        .onExitCommand { handleMenuButton() }
        .onTapGesture { toggleOverlay() }
        .onChange(of: vlcWrapper.isPlaying) { _, playing in
            viewModel?.isPlaying = playing
        }
        .onChange(of: vlcWrapper.isBuffering) { _, buffering in
            viewModel?.isBuffering = buffering
        }
        .onChange(of: vlcWrapper.currentTimeMs) { _, timeMs in
            syncTimeToViewModel(timeMs: timeMs)
        }
        .onChange(of: vlcWrapper.durationMs) { _, durationMs in
            viewModel?.duration = durationMs * 10_000 // ms → ticks
        }
    }

    // MARK: - Playback Lifecycle

    private func startPlayback() {
        let vm = PlayerViewModel(itemId: itemId, client: jellyfinClient)
        viewModel = vm

        Task {
            do {
                let url = try await vm.loadPlaybackInfo()

                // Load external subtitles
                for sub in vm.externalSubtitleURLs() {
                    vlcWrapper.loadExternalSubtitle(url: sub.url)
                }

                // Load segments for skip intro/outro
                await vm.loadSegments()

                // Load next episode for Up Next
                if let item = currentItem {
                    await vm.loadNextEpisode(currentItem: item)
                }

                // Start VLC playback
                vlcWrapper.playURL(url)
                hasStarted = true

                // Report start
                await vm.reportStart()

                // Start periodic progress reporting
                startProgressReporting()

                // Schedule auto-hide
                scheduleAutoHide()
            } catch {
                vm.error = error.localizedDescription
            }
        }
    }

    private func stopPlayback() {
        hideTask?.cancel()
        progressReportTask?.cancel()

        Task {
            await viewModel?.reportStop()
        }

        vlcWrapper.cleanup()
    }

    // MARK: - Time Sync

    private func syncTimeToViewModel(timeMs: Int64) {
        guard let vm = viewModel else { return }
        let ticks = timeMs * 10_000 // ms → Jellyfin ticks
        vm.currentTime = ticks
        vm.checkUpNextTrigger()

        // Auto-play next when playback ends
        if vm.shouldAutoPlayNext && vlcWrapper.durationMs > 0 &&
            timeMs >= vlcWrapper.durationMs - 500 {
            playNextEpisode()
        }
    }

    // MARK: - Progress Reporting

    private func startProgressReporting() {
        progressReportTask?.cancel()
        progressReportTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled else { break }
                await viewModel?.reportProgress()
            }
        }
    }

    // MARK: - Remote Input

    private func handlePlayPause() {
        vlcWrapper.togglePlayPause()
        if overlayVisible {
            viewModel?.resetOverlayTimer()
            scheduleAutoHide()
        }
    }

    private func handleMenuButton() {
        if overlayVisible {
            hideOverlay()
        } else {
            // Dismiss the player
            Task {
                await viewModel?.reportStop()
            }
            vlcWrapper.cleanup()
            dismiss()
        }
    }

    private func toggleOverlay() {
        if overlayVisible {
            hideOverlay()
        } else {
            showOverlay()
        }
    }

    private func showOverlay() {
        overlayVisible = true
        viewModel?.showOverlay = true
        scheduleAutoHide()
    }

    private func hideOverlay() {
        hideTask?.cancel()
        overlayVisible = false
        viewModel?.showOverlay = false
    }

    private func scheduleAutoHide() {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                hideOverlay()
            }
        }
    }

    // MARK: - Up Next

    private func playNextEpisode() {
        guard let nextEp = viewModel?.nextEpisode else { return }

        // Stop current playback
        vlcWrapper.stop()
        viewModel?.resetUpNextState()

        // Start new episode
        let newVM = PlayerViewModel(itemId: nextEp.id, client: jellyfinClient)
        viewModel = newVM

        Task {
            do {
                let url = try await newVM.loadPlaybackInfo()
                await newVM.loadSegments()
                await newVM.loadNextEpisode(currentItem: nextEp)

                vlcWrapper.playURL(url)
                await newVM.reportStart()
                startProgressReporting()
                scheduleAutoHide()
            } catch {
                newVM.error = error.localizedDescription
            }
        }
    }
}
