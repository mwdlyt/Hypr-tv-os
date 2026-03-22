import AVKit
import UIKit
import os

/// Presents AVPlayerViewController using native UIKit modal presentation.
/// Handles audio track switching and subtitle loading.
@MainActor
final class PlayerLauncher: NSObject {

    static let shared = PlayerLauncher()
    private let logger = Logger(subsystem: "com.hypr.tv", category: "PlayerLauncher")

    private var playerVC: AVPlayerViewController?
    private var dismissCheckTask: Task<Void, Never>?

    // Current playback state (for track switching)
    private var currentItemId: String?
    private var currentClient: JellyfinClient?
    private var currentSource: MediaSourceDTO?
    private var currentPlaySessionId: String?
    private var currentAudioIndex: Int?
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

                // Find default audio index
                let defaultAudioIndex = audioTracks.first(where: { $0.isDefault })?.id
                    ?? audioTracks.first?.id ?? 1

                // Store state for track switching
                currentItemId = itemId
                currentClient = client
                currentSource = source
                currentPlaySessionId = response.playSessionId
                currentAudioIndex = defaultAudioIndex

                let streamURL = buildStreamURL(
                    source: source,
                    itemId: itemId,
                    playSessionId: response.playSessionId,
                    audioStreamIndex: defaultAudioIndex,
                    client: client
                )

                guard let streamURL else {
                    logger.error("Could not determine stream URL for \(itemId)")
                    return
                }

                logger.info("Playing: \(item?.name ?? itemId)")
                logger.info("Audio tracks: \(self.audioTracks.count), Subtitle tracks: \(self.subtitleTracks.count)")

                // Create player
                let player = AVPlayer(url: streamURL)

                // Set metadata
                var metadata: [AVMetadataItem] = []
                if let name = item?.name {
                    let titleItem = AVMutableMetadataItem()
                    titleItem.identifier = .commonIdentifierTitle
                    titleItem.value = name as NSString
                    metadata.append(titleItem)
                }
                player.currentItem?.externalMetadata = metadata

                // Resume position
                if let ticks = item?.userData?.playbackPositionTicks, ticks > 0 {
                    let seconds = Double(ticks) / 10_000_000.0
                    await player.seek(to: CMTime(seconds: seconds, preferredTimescale: 1000))
                }

                // Present player with custom info panel
                let vc = AVPlayerViewController()
                vc.player = player
                vc.showsPlaybackControls = true

                // Add custom info view controller for audio/subtitle selection
                let infoVC = TrackSelectionViewController(
                    audioTracks: audioTracks,
                    subtitleTracks: subtitleTracks,
                    currentAudioIndex: defaultAudioIndex,
                    onAudioSelected: { [weak self] audioIndex in
                        self?.switchAudioTrack(to: audioIndex)
                    },
                    onSubtitleSelected: { [weak self] subtitleIndex in
                        self?.loadSubtitle(index: subtitleIndex)
                    }
                )
                vc.customInfoViewController = infoVC

                self.playerVC = vc

                guard let rootVC = self.topViewController() else {
                    logger.error("No root view controller")
                    self.playerVC = nil
                    return
                }

                vc.modalPresentationStyle = .fullScreen
                rootVC.present(vc, animated: true) {
                    player.play()
                    self.logger.info("Player presented — playback started")
                }

                // Report start
                try? await client.reportPlaybackStart(
                    itemId: itemId,
                    mediaSourceId: source.id,
                    playSessionId: response.playSessionId
                )

                // Monitor dismiss
                self.startDismissMonitor(itemId: itemId, client: client, playSessionId: response.playSessionId)

            } catch {
                logger.error("Failed to launch: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Audio Track Switching

    /// Switches the audio track by rebuilding the HLS stream URL with a different AudioStreamIndex.
    /// Preserves the current playback position.
    private func switchAudioTrack(to audioIndex: Int) {
        guard let vc = playerVC,
              let player = vc.player,
              let itemId = currentItemId,
              let client = currentClient,
              let source = currentSource else { return }

        // Save current position
        let currentTime = player.currentTime()
        currentAudioIndex = audioIndex

        logger.info("Switching to audio track index \(audioIndex)")

        // Build new URL with different audio index
        guard let newURL = buildStreamURL(
            source: source,
            itemId: itemId,
            playSessionId: currentPlaySessionId,
            audioStreamIndex: audioIndex,
            client: client
        ) else { return }

        // Replace the player item
        let newItem = AVPlayerItem(url: newURL)
        player.replaceCurrentItem(with: newItem)

        // Seek to where we were
        Task {
            await player.seek(to: currentTime)
            player.play()
        }
    }

    // MARK: - Subtitle Loading

    /// Loads an external subtitle track from Jellyfin and adds it to the player.
    private func loadSubtitle(index: Int?) {
        guard let vc = playerVC,
              let player = vc.player,
              let playerItem = player.currentItem,
              let itemId = currentItemId,
              let client = currentClient,
              let source = currentSource else { return }

        // index == nil means "Off"
        guard let index else {
            // Disable subtitles — select no legible option
            if let group = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) {
                playerItem.select(nil, in: group)
            }
            logger.info("Subtitles disabled")
            return
        }

        // Build subtitle URL
        guard let subtitleURL = client.subtitleURL(
            itemId: itemId,
            mediaSourceId: source.id,
            subtitleIndex: index
        ) else { return }

        logger.info("Loading subtitle index \(index) from \(subtitleURL)")

        // Add as external subtitle
        // AVPlayer supports adding VTT subtitles as supplementary content
        Task {
            // For HLS streams, we can't add external subtitles directly.
            // Instead, we'll use the Jellyfin subtitle burn-in approach:
            // Rebuild the HLS URL with SubtitleStreamIndex parameter
            let currentTime = player.currentTime()

            guard var newURL = buildStreamURL(
                source: source,
                itemId: itemId,
                playSessionId: currentPlaySessionId,
                audioStreamIndex: currentAudioIndex ?? 1,
                subtitleStreamIndex: index,
                client: client
            ) else { return }

            let newItem = AVPlayerItem(url: newURL)
            player.replaceCurrentItem(with: newItem)
            await player.seek(to: currentTime)
            player.play()
            logger.info("Subtitle track \(index) activated (burn-in)")
        }
    }

    // MARK: - Stream URL Building

    private func buildStreamURL(
        source: MediaSourceDTO,
        itemId: String,
        playSessionId: String?,
        audioStreamIndex: Int = 1,
        subtitleStreamIndex: Int? = nil,
        client: JellyfinClient
    ) -> URL? {
        guard let baseURL = client.baseURL else { return nil }

        // Option 1: Use transcoding URL from server (modify audio/subtitle indices)
        if let transcodingPath = source.transcodingUrl, !transcodingPath.isEmpty {
            // The TranscodingUrl already has AudioStreamIndex — we need to replace it
            var modifiedPath = transcodingPath

            // Replace AudioStreamIndex
            if let range = modifiedPath.range(of: "AudioStreamIndex=\\d+", options: .regularExpression) {
                modifiedPath.replaceSubrange(range, with: "AudioStreamIndex=\(audioStreamIndex)")
            } else {
                modifiedPath += "&AudioStreamIndex=\(audioStreamIndex)"
            }

            // Add or replace SubtitleStreamIndex
            if let subIndex = subtitleStreamIndex {
                if let range = modifiedPath.range(of: "SubtitleStreamIndex=\\d+", options: .regularExpression) {
                    modifiedPath.replaceSubrange(range, with: "SubtitleStreamIndex=\(subIndex)")
                } else {
                    modifiedPath += "&SubtitleStreamIndex=\(subIndex)&SubtitleMethod=Encode"
                }
            } else {
                // Remove subtitle params if present
                modifiedPath = modifiedPath.replacingOccurrences(
                    of: "&SubtitleStreamIndex=\\d+", with: "", options: .regularExpression
                )
                modifiedPath = modifiedPath.replacingOccurrences(
                    of: "&SubtitleMethod=Encode", with: ""
                )
            }

            if let url = URL(string: modifiedPath, relativeTo: baseURL) {
                logger.info("Using TranscodingUrl (audio=\(audioStreamIndex), sub=\(subtitleStreamIndex ?? -1))")
                return url.absoluteURL
            }
        }

        // Option 2: Direct stream for compatible containers
        let container = source.container?.lowercased() ?? ""
        if ["mp4", "m4v", "mov"].contains(where: { container.contains($0) }) {
            if let token = client.accessToken {
                var components = URLComponents(
                    url: baseURL.appendingPathComponent("/Videos/\(itemId)/stream"),
                    resolvingAgainstBaseURL: false
                )
                components?.queryItems = [
                    URLQueryItem(name: "static", value: "true"),
                    URLQueryItem(name: "api_key", value: token),
                    URLQueryItem(name: "MediaSourceId", value: source.id)
                ]
                if let url = components?.url {
                    return url
                }
            }
        }

        // Option 3: Fallback HLS
        return client.streamURL(itemId: itemId, mediaSourceId: source.id, playSessionId: playSessionId)
    }

    // MARK: - Dismiss

    func dismiss() {
        playerVC?.player?.pause()
        playerVC?.dismiss(animated: true) { [weak self] in
            self?.cleanup()
        }
    }

    private func startDismissMonitor(itemId: String, client: JellyfinClient, playSessionId: String?) {
        dismissCheckTask?.cancel()
        dismissCheckTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard let self, let vc = self.playerVC else { break }

                if vc.presentingViewController == nil && vc.view.window == nil {
                    let positionTicks = Int64((vc.player?.currentTime().seconds ?? 0) * 10_000_000)
                    try? await client.reportPlaybackStopped(
                        itemId: itemId,
                        positionTicks: positionTicks,
                        playSessionId: playSessionId
                    )
                    self.cleanup()
                    break
                }
            }
        }
    }

    private func cleanup() {
        dismissCheckTask?.cancel()
        dismissCheckTask = nil
        playerVC?.player?.pause()
        playerVC?.player = nil
        playerVC = nil
        currentItemId = nil
        currentClient = nil
        currentSource = nil
        currentPlaySessionId = nil
        currentAudioIndex = nil
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
