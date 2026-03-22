import AVKit
import UIKit
import os

/// Presents AVPlayerViewController using UIKit modal presentation.
/// This is the only reliable way to get native tvOS player controls + Menu button.
@MainActor
final class PlayerLauncher: NSObject {

    static let shared = PlayerLauncher()
    private let logger = Logger(subsystem: "com.hypr.tv", category: "PlayerLauncher")

    private var playerVC: AVPlayerViewController?
    private var onDismiss: (() -> Void)?
    private var dismissObservation: NSKeyValueObservation?

    private override init() { super.init() }

    /// Present AVPlayerViewController modally from the top-most view controller.
    func present(player: AVPlayer, title: String? = nil, onDismiss: @escaping () -> Void) {
        // Prevent double-presentation
        if playerVC != nil { return }

        self.onDismiss = onDismiss

        let vc = AVPlayerViewController()
        vc.player = player
        vc.showsPlaybackControls = true

        // Set title metadata for transport bar
        if let title {
            let titleItem = AVMutableMetadataItem()
            titleItem.identifier = .commonIdentifierTitle
            titleItem.value = title as NSString
            player.currentItem?.externalMetadata = [titleItem]
        }

        self.playerVC = vc

        guard let rootVC = topViewController() else {
            logger.error("No root view controller available")
            onDismiss()
            return
        }

        vc.modalPresentationStyle = .fullScreen
        vc.modalTransitionStyle = .crossDissolve

        rootVC.present(vc, animated: true) {
            player.play()
            self.logger.info("Player presented and playing")
        }

        // KVO: watch for when the VC is dismissed (Menu button triggers this)
        dismissObservation = vc.observe(\.isBeingDismissed, options: [.new]) { [weak self] _, _ in
            self?.handleDismiss()
        }

        // Also start a lightweight check for when the VC disappears
        startDismissMonitor()
    }

    /// Programmatically dismiss the player.
    func dismiss() {
        guard let vc = playerVC else { return }
        vc.player?.pause()
        vc.dismiss(animated: true) { [weak self] in
            self?.handleDismiss()
        }
    }

    private func handleDismiss() {
        guard playerVC != nil else { return } // already handled
        dismissObservation?.invalidate()
        dismissObservation = nil
        playerVC?.player?.pause()
        playerVC?.player = nil
        playerVC = nil
        let callback = onDismiss
        onDismiss = nil
        callback?()
        logger.info("Player dismissed and cleaned up")
    }

    /// Monitor for when AVPlayerVC gets dismissed by the system (Menu button).
    private func startDismissMonitor() {
        Task { @MainActor [weak self] in
            // Check every 0.5s if the playerVC is still presented
            while let self = self, let vc = self.playerVC {
                try? await Task.sleep(nanoseconds: 500_000_000)
                if vc.presentingViewController == nil && vc.view.window == nil {
                    self.handleDismiss()
                    break
                }
            }
        }
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
