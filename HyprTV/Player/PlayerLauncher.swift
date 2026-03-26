import UIKit
import os

/// Presents VLCPlayerViewController using native UIKit modal presentation.
/// Handles audio/subtitle track switching via VLCKit's native capabilities.
@MainActor
final class PlayerLauncher: NSObject {

    static let shared = PlayerLauncher()
    private let logger = Logger(subsystem: "com.hypr.tv", category: "PlayerLauncher")

    private var playerVC: VLCPlayerViewController?
    private var playerWrapper: VLCPlayerWrapper?
    private var coordinator: PlaybackCoordinator?
    private var dismissCheckTask: Task<Void, Never>?

    // Current playback state (for track switching)
    private var currentItemId: String?
    private var currentClient: JellyfinClient?
    private var currentSource: MediaSourceDTO?
    private var currentPlaySessionId: String?
    private var audioTracks: [AudioTrack] = []
    private var subtitleTracks: [SubtitleTrack] = []

    private override init() { super.init() }

    // MARK: - Launch

    func launch(itemId: String, client: JellyfinClient) {
        guard playerVC == nil else {
            logger.warning("Player already presented, ignoring launch")
            return
        }

        Task { @MainActor in
            do {
                let item = try? await client.getItem(id: itemId)

                let response = try await client.getPlaybackInfo(itemId: itemId)
                guard let source = response.mediaSources.first else {
                    logger.error("No media source found for \(itemId)")
                    return
                }

                // Parse audio and subtitle tracks
                audioTracks = MediaTrackParser.audioTracks(from: source.mediaStreams)
                subtitleTracks = MediaTrackParser.subtitleTracks(from: source.mediaStreams)

                // Store state
                currentItemId = itemId
                currentClient = client
                currentSource = source
                currentPlaySessionId = response.playSessionId

                // Build direct stream URL — VLC handles all containers and codecs natively
                guard let streamURL = client.streamURL(
                    itemId: itemId,
                    mediaSourceId: source.id,
                    playSessionId: response.playSessionId
                ) else {
                    logger.error("Could not determine stream URL for \(itemId)")
                    return
                }

                logger.info("Playing: \(item?.name ?? itemId)")
                logger.info("Stream URL: \(streamURL.absoluteString, privacy: .private)")
                logger.info("Audio tracks: \(self.audioTracks.count), Subtitle tracks: \(self.subtitleTracks.count)")

                // Create VLC player wrapper
                let wrapper = VLCPlayerWrapper()
                self.playerWrapper = wrapper

                // Create VLC view controller
                let vc = VLCPlayerViewController(playerWrapper: wrapper)
                vc.onMenuPressed = { [weak self] in
                    self?.dismiss()
                }
                self.playerVC = vc

                guard let rootVC = self.topViewController() else {
                    logger.error("No root view controller")
                    self.playerVC = nil
                    self.playerWrapper = nil
                    return
                }

                vc.modalPresentationStyle = .fullScreen
                rootVC.present(vc, animated: true) { [weak self] in
                    guard let self else { return }

                    // Start playback
                    wrapper.playURL(streamURL)

                    // Resume position
                    if let ticks = item?.userData?.playbackPositionTicks, ticks > 0 {
                        let positionMs = ticks / 10_000  // ticks to milliseconds
                        wrapper.seek(to: positionMs)
                        self.logger.info("Resuming at \(positionMs)ms")
                    }

                    // Load external subtitles from Jellyfin
                    self.loadExternalSubtitles(source: source, itemId: itemId, client: client, wrapper: wrapper)

                    self.logger.info("VLC player presented — playback started")
                }

                // Set up PlaybackCoordinator
                let coord = PlaybackCoordinator(client: client, itemId: itemId)
                coord.setPlaySessionId(response.playSessionId)
                self.coordinator = coord

                // Report start
                await coord.reportStart()

                // Start progress reporting
                coord.startProgressReporting(
                    positionProvider: { [weak wrapper] in
                        wrapper?.currentTimeMs ?? 0
                    },
                    isPausedProvider: { [weak wrapper] in
                        !(wrapper?.isPlaying ?? false)
                    }
                )

                // Monitor dismiss
                self.startDismissMonitor()

            } catch {
                logger.error("Failed to launch: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Audio Track Switching

    /// Switches the audio track instantly via VLC — no URL rebuild needed.
    func switchAudioTrack(to jellyfinIndex: Int) {
        guard let wrapper = playerWrapper else { return }

        logger.info("Switching to audio track index \(jellyfinIndex)")

        // VLC audio track indices map to their internal order.
        // Find the VLC track matching the Jellyfin stream index.
        // VLC exposes tracks as (index, title) pairs. The VLC index for embedded
        // streams typically starts at 1 (0 = "Disable"). We map Jellyfin stream
        // indices to VLC track indices by matching order.
        let vlcTracks = wrapper.audioTracks
        if let match = vlcTracks.first(where: { $0.index == jellyfinIndex }) {
            wrapper.setAudioTrack(index: match.index)
        } else {
            // Fallback: try using the Jellyfin index directly
            wrapper.setAudioTrack(index: jellyfinIndex)
        }
    }

    // MARK: - Subtitle Track Switching

    /// Switches subtitle track instantly via VLC — no URL rebuild needed.
    func switchSubtitleTrack(to jellyfinIndex: Int?) {
        guard let wrapper = playerWrapper else { return }

        guard let jellyfinIndex else {
            // Disable subtitles
            wrapper.setSubtitleTrack(index: -1)
            logger.info("Subtitles disabled")
            return
        }

        logger.info("Switching to subtitle track index \(jellyfinIndex)")

        let vlcTracks = wrapper.subtitleTracks
        if let match = vlcTracks.first(where: { $0.index == jellyfinIndex }) {
            wrapper.setSubtitleTrack(index: match.index)
        } else {
            wrapper.setSubtitleTrack(index: jellyfinIndex)
        }
    }

    // MARK: - External Subtitles

    /// Loads external subtitle streams from Jellyfin into VLC.
    private func loadExternalSubtitles(
        source: MediaSourceDTO,
        itemId: String,
        client: JellyfinClient,
        wrapper: VLCPlayerWrapper
    ) {
        let externalSubs = subtitleTracks.filter { $0.isExternal }
        for sub in externalSubs {
            let format = sub.codec ?? "srt"
            if let url = client.subtitleURL(
                itemId: itemId,
                mediaSourceId: source.id,
                streamIndex: sub.id,
                format: format
            ) {
                wrapper.loadExternalSubtitle(url: url)
                logger.info("Loaded external subtitle: \(sub.label) (\(format))")
            }
        }
    }

    // MARK: - Dismiss

    func dismiss() {
        guard let vc = playerVC else { return }
        let wrapper = playerWrapper
        let coord = coordinator

        // Report stop with final position
        let positionMs = wrapper?.currentTimeMs ?? 0
        let positionTicks = positionMs * 10_000

        wrapper?.stop()

        vc.dismiss(animated: true) { [weak self] in
            Task {
                await coord?.reportStop(positionTicks: positionTicks)
            }
            self?.cleanup()
        }
    }

    private func startDismissMonitor() {
        dismissCheckTask?.cancel()
        dismissCheckTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard let self, let vc = self.playerVC else { break }

                if vc.presentingViewController == nil && vc.view.window == nil {
                    let positionMs = self.playerWrapper?.currentTimeMs ?? 0
                    let positionTicks = positionMs * 10_000
                    await self.coordinator?.reportStop(positionTicks: positionTicks)
                    self.cleanup()
                    break
                }
            }
        }
    }

    private func cleanup() {
        dismissCheckTask?.cancel()
        dismissCheckTask = nil
        playerWrapper?.cleanup()
        playerWrapper = nil
        coordinator?.stopReporting()
        coordinator = nil
        playerVC = nil
        currentItemId = nil
        currentClient = nil
        currentSource = nil
        currentPlaySessionId = nil
        audioTracks = []
        subtitleTracks = []
        logger.info("Player cleaned up")
    }

    private func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first,
              let rootVC = scene.windows.first?.rootViewController else {
            return nil
        }
        var top = rootVC
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}
