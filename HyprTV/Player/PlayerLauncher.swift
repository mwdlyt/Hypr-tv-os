import AVKit
import UIKit
import os

/// Presents AVPlayerViewController using native UIKit modal presentation.
/// This is the ONLY way to get proper rendering + Siri Remote controls on tvOS.
/// SwiftUI fullScreenCover/ZStack approaches don't work for AVPlayerViewController.
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
                // 1. Get item details for metadata
                let item = try? await client.getItem(id: itemId)

                // 2. Get playback info and stream URL
                let response = try await client.getPlaybackInfo(itemId: itemId)
                guard let source = response.mediaSources.first else {
                    logger.error("No media source found for \(itemId)")
                    return
                }

                // Use the server-provided TranscodingUrl if available (means we need transcoding).
                // Otherwise fall back to our built stream URL (direct stream).
                let streamURL: URL
                if let transcodingPath = source.transcodingUrl,
                   let base = client.baseURL {
                    // TranscodingUrl is a relative path — prepend the server base URL
                    guard let fullURL = URL(string: transcodingPath, relativeTo: base) else {
                        logger.error("Invalid transcoding URL: \(transcodingPath)")
                        return
                    }
                    streamURL = fullURL.absoluteURL
                    logger.info("Using server TranscodingUrl (transcode/remux)")
                } else {
                    // Direct play — use our stream URL builder
                    guard let url = client.streamURL(itemId: itemId, mediaSourceId: source.id, playSessionId: response.playSessionId) else {
                        logger.error("Could not build stream URL for \(itemId)")
                        return
                    }
                    streamURL = url
                    logger.info("Using direct stream URL")
                }

                logger.info("Stream URL: \(streamURL.absoluteString.prefix(200))")

                // 3. Create AVPlayer
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

                // Build subtitle: "S1:E5 · Episode Name" or "2024 · PG-13"
                var subtitleParts: [String] = []
                if let item, item.type == .episode {
                    if let season = item.parentIndexNumber, let episode = item.indexNumber {
                        subtitleParts.append("S\(season):E\(episode)")
                    }
                    if let seriesName = item.seriesName {
                        subtitleParts.append(seriesName)
                    }
                } else {
                    if let year = item?.productionYear { subtitleParts.append(String(year)) }
                    if let rating = item?.officialRating { subtitleParts.append(rating) }
                }

                if !subtitleParts.isEmpty {
                    let descItem = AVMutableMetadataItem()
                    descItem.identifier = .commonIdentifierDescription
                    descItem.value = subtitleParts.joined(separator: " · ") as NSString
                    metadata.append(descItem)
                }

                playerItem.externalMetadata = metadata

                let player = AVPlayer(playerItem: playerItem)

                // 4. Resume from saved position
                if let ticks = item?.userData?.playbackPositionTicks, ticks > 0 {
                    let seconds = Double(ticks) / 10_000_000.0
                    await player.seek(to: CMTime(seconds: seconds, preferredTimescale: 1000))
                }

                // 5. Present AVPlayerViewController natively
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
                    self.logger.info("Player presented — playing \(item?.name ?? itemId)")
                }

                // 6. Report playback start to Jellyfin
                try? await client.reportPlaybackStart(
                    itemId: itemId,
                    mediaSourceId: source.id,
                    playSessionId: response.playSessionId
                )

                // 7. Monitor for dismissal (Menu button)
                self.startDismissMonitor(itemId: itemId, client: client, playSessionId: response.playSessionId)

            } catch {
                logger.error("Failed to launch player: \(error.localizedDescription)")
            }
        }
    }

    /// Dismiss the player programmatically.
    func dismiss() {
        playerVC?.player?.pause()
        playerVC?.dismiss(animated: true) { [weak self] in
            self?.cleanup()
        }
    }

    // MARK: - Private

    /// Polls to detect when AVPlayerViewController is dismissed via Menu button.
    private func startDismissMonitor(itemId: String, client: JellyfinClient, playSessionId: String?) {
        dismissCheckTask?.cancel()
        dismissCheckTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard let self, let vc = self.playerVC else { break }

                // Check if the VC has been dismissed
                if vc.presentingViewController == nil && vc.view.window == nil {
                    // Report stop position to Jellyfin
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
