import SwiftUI

/// Main player view combining VLC video rendering with custom overlay controls.
/// Handles Siri Remote input for play/pause, overlay toggle, seeking, and dismissal.
struct PlayerView: View {

    init(itemId: String, currentItem: MediaItemDTO?) {
        self._activeItemId = State(initialValue: itemId)
        self._currentItem = State(initialValue: currentItem)
    }

    @Environment(JellyfinClient.self) private var jellyfinClient
    @Environment(\.dismiss) private var dismiss

    /// The id and metadata of the item currently playing. These change when
    /// the Up Next flow auto-advances to the next episode.
    @State private var activeItemId: String
    @State private var currentItem: MediaItemDTO?

    @State private var viewModel: PlayerViewModel?
    @State private var vlcWrapper = VLCPlayerWrapper()
    @State private var overlayVisible = true
    @State private var hideTask: Task<Void, Never>?
    @State private var progressReportTask: Task<Void, Never>?
    @State private var hasStarted = false

    /// Controls the Infuse-style Audio / Subtitles / Speed / Info panel.
    @State private var showInfoPanel = false
    /// Pause state to restore when the info panel is dismissed.
    @State private var wasPlayingBeforePanel = false

    var body: some View {
        ZStack {
            // VLC video layer
            PlayerRepresentable(playerWrapper: vlcWrapper)
                .ignoresSafeArea()

            // Buffering spinner (centered, shown when overlay is hidden)
            if vlcWrapper.isBuffering && !overlayVisible && !showInfoPanel {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            }

            // Transport overlay — hidden while the info panel is up so the
            // two surfaces don't fight for focus.
            if overlayVisible, !showInfoPanel, let vm = viewModel {
                PlayerOverlayView(
                    viewModel: vm,
                    vlcWrapper: vlcWrapper,
                    currentItem: currentItem,
                    onShowInfoPanel: { presentInfoPanel() }
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

            // Up Next overlay (hidden while panel is open)
            if !showInfoPanel, let vm = viewModel, vm.showUpNext, let nextEp = vm.nextEpisode {
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

            // Infuse-style bottom panel — slides up over the video without
            // dismissing playback. Triggered by swipe-down or by tapping the
            // Audio/CC buttons in the transport overlay.
            if showInfoPanel, let vm = viewModel {
                PlayerInfoPanel(
                    viewModel: vm,
                    vlcWrapper: vlcWrapper,
                    onClose: { dismissInfoPanel() }
                )
                .zIndex(100)
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .persistentSystemOverlays(.hidden)
        .focusable(true)
        .onAppear { startPlayback() }
        .onDisappear { stopPlayback() }
        .onPlayPauseCommand { handlePlayPause() }
        .onExitCommand { handleMenuButton() }
        .onMoveCommand { direction in
            // Swipe / d-pad down on the Siri Remote summons the info panel,
            // matching Infuse's gesture. Ignored while the panel is already
            // open — inside the panel its own focus controls take over.
            guard !showInfoPanel, direction == .down else { return }
            presentInfoPanel()
        }
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
        .animation(.easeInOut(duration: 0.3), value: showInfoPanel)
    }

    // MARK: - Info Panel

    private func presentInfoPanel() {
        guard !showInfoPanel else { return }
        // Cancel the auto-hide timer so the transport bar doesn't race the panel.
        hideTask?.cancel()

        wasPlayingBeforePanel = vlcWrapper.isPlaying
        // Match Infuse's behaviour: pause the video so users can read info
        // and swap tracks without missing dialogue.
        vlcWrapper.pause()

        overlayVisible = false
        showInfoPanel = true
    }

    private func dismissInfoPanel() {
        guard showInfoPanel else { return }
        showInfoPanel = false

        // Resume playback only if we paused it when opening.
        if wasPlayingBeforePanel {
            vlcWrapper.play()
        }
        wasPlayingBeforePanel = false

        // Re-show the transport bar briefly so users can orient themselves.
        overlayVisible = true
        viewModel?.showOverlay = true
        scheduleAutoHide()
    }

    // MARK: - Playback Lifecycle

    private func startPlayback() {
        let vm = PlayerViewModel(itemId: activeItemId, client: jellyfinClient)
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
        hideTask = nil
        progressReportTask?.cancel()
        progressReportTask = nil

        // Capture the VM locally so the dismissed view doesn't drop the report.
        let vmToStop = viewModel
        Task {
            await vmToStop?.reportStop()
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

        // Capture the old VM before replacing so we can report stop on the
        // server. Without this the Jellyfin session just dangles and
        // Continue Watching keeps the old episode forever.
        let oldVM = viewModel
        progressReportTask?.cancel()
        progressReportTask = nil

        // Stop current playback and reset Up Next state on the old VM.
        vlcWrapper.stop()
        oldVM?.resetUpNextState()

        // Start new episode
        let newVM = PlayerViewModel(itemId: nextEp.id, client: jellyfinClient)
        viewModel = newVM
        activeItemId = nextEp.id
        currentItem = nextEp

        Task {
            // Finalise the old episode on the server before the new one starts.
            await oldVM?.reportStop()

            do {
                let url = try await newVM.loadPlaybackInfo()
                for sub in newVM.externalSubtitleURLs() {
                    vlcWrapper.loadExternalSubtitle(url: sub.url)
                }
                await newVM.loadSegments()
                await newVM.loadNextEpisode(currentItem: nextEp)

                vlcWrapper.playURL(url)
                await newVM.reportStart()
                startProgressReporting()
                showOverlay()
            } catch {
                newVM.error = error.localizedDescription
            }
        }
    }
}
