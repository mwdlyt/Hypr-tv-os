import AVKit
import UIKit
import os

/// Presents AVPlayerViewController using native UIKit modal presentation.
/// This is the ONLY way to get proper rendering + Siri Remote controls on tvOS.
@MainActor
final class PlayerLauncher: NSObject {

    static let shared = PlayerLauncher()
    private let logger = Logger(subsystem: "com.hypr.tv", category: "PlayerLauncher")

    private var playerVC: AVPlayerViewController?
    private var dismissCheckTask: Task<Void, Never>?

    private override init() { super.init() }

    /// Load media info from Jellyfin and present the native player.
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

                let streamURL = buildStreamURL(
                    source: source,
                    itemId: itemId,
                    playSessionId: response.playSessionId,
                    client: client
                )

                guard let streamURL else {
                    logger.error("Could not determine stream URL for \(itemId)")
                    return
                }

                logger.info("Playing: \(item?.name ?? itemId)")
                logger.info("Container: \(source.container ?? "?")")
                logger.info("Stream URL: \(streamURL.absoluteString.prefix(150))")

                // Create AVPlayer with the stream URL
                let asset = AVURLAsset(url: streamURL)
                let playerItem = AVPlayerItem(asset: asset)

                // Set metadata for native transport bar
                var metadata: [AVMetadataItem] = []
                if let name = item?.name {
                    let titleItem = AVMutableMetadataItem()
                    titleItem.identifier = .commonIdentifierTitle
                    titleItem.value = name as NSString
                    metadata.append(titleItem)
                }
                playerItem.externalMetadata = metadata

                let player = AVPlayer(playerItem: playerItem)

                // Observe for errors
                let errorObserver = playerItem.observe(\.status) { item, _ in
                    if item.status == .failed {
                        print("❌ AVPlayerItem FAILED: \(item.error?.localizedDescription ?? "unknown")")
                    } else if item.status == .readyToPlay {
                        print("✅ AVPlayerItem ready to play")
                    }
                }

                // Resume from saved position
                if let ticks = item?.userData?.playbackPositionTicks, ticks > 0 {
                    let seconds = Double(ticks) / 10_000_000.0
                    await player.seek(to: CMTime(seconds: seconds, preferredTimescale: 1000))
                }

                // Present AVPlayerViewController
                let vc = AVPlayerViewController()
                vc.player = player
                vc.showsPlaybackControls = true
                self.playerVC = vc

                guard let rootVC = self.topViewController() else {
                    logger.error("No root view controller available")
                    self.playerVC = nil
                    return
                }

                vc.modalPresentationStyle = .fullScreen
                rootVC.present(vc, animated: true) {
                    player.play()
                    self.logger.info("Player presented — playback started")
                }

                // Report playback start
                try? await client.reportPlaybackStart(
                    itemId: itemId,
                    mediaSourceId: source.id,
                    playSessionId: response.playSessionId
                )

                // Monitor for dismissal
                self.startDismissMonitor(
                    itemId: itemId,
                    client: client,
                    playSessionId: response.playSessionId
                )

                // Hold error observer reference
                withExtendedLifetime(errorObserver) {}

            } catch {
                logger.error("Failed to launch player: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Stream URL Selection

    /// Determines the best stream URL based on what Jellyfin reports.
    /// Priority: TranscodingUrl (Jellyfin decided) > Direct Stream > Fallback HLS
    private func buildStreamURL(
        source: MediaSourceDTO,
        itemId: String,
        playSessionId: String?,
        client: JellyfinClient
    ) -> URL? {
        guard let baseURL = client.baseURL else { return nil }

        // Option 1: Server provided a transcoding URL — use it.
        // This means Jellyfin decided the content needs transcoding/remuxing.
        if let transcodingPath = source.transcodingUrl, !transcodingPath.isEmpty {
            if let url = URL(string: transcodingPath, relativeTo: baseURL) {
                logger.info("Using TranscodingUrl from server")
                return url.absoluteURL
            }
        }

        // Option 2: Content can be direct streamed.
        // For MP4/MOV containers with compatible codecs, just stream the file.
        let container = source.container?.lowercased() ?? ""
        if ["mp4", "m4v", "mov"].contains(where: { container.contains($0) }) {
            if let token = client.accessToken {
                var components = URLComponents(url: baseURL.appendingPathComponent("/Videos/\(itemId)/stream"), resolvingAgainstBaseURL: false)
                components?.queryItems = [
                    URLQueryItem(name: "static", value: "true"),
                    URLQueryItem(name: "api_key", value: token),
                    URLQueryItem(name: "MediaSourceId", value: source.id)
                ]
                if let url = components?.url {
                    logger.info("Using direct static stream (compatible container: \(container))")
                    return url
                }
            }
        }

        // Option 3: Fallback to our HLS URL builder
        return client.streamURL(itemId: itemId, mediaSourceId: source.id, playSessionId: playSessionId)
    }

    /// Dismiss the player programmatically.
    func dismiss() {
        playerVC?.player?.pause()
        playerVC?.dismiss(animated: true) { [weak self] in
            self?.cleanup()
        }
    }

    // MARK: - Private

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
