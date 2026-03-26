import UIKit
import SwiftUI
import os

/// Presents the VLC-based player as a UIKit modal.
/// Uses PlayerView (SwiftUI) which combines VLC video + custom overlay controls.
@MainActor
final class PlayerLauncher: NSObject {

    static let shared = PlayerLauncher()
    private let logger = Logger(subsystem: "com.hypr.tv", category: "PlayerLauncher")

    private var hostingVC: UIViewController?
    private var dismissCheckTask: Task<Void, Never>?

    private override init() { super.init() }

    // MARK: - Launch

    func launch(itemId: String, client: JellyfinClient) {
        guard hostingVC == nil else {
            logger.warning("Player already presented, ignoring launch")
            return
        }

        // Fetch item metadata for the player
        Task { @MainActor in
            let item = try? await client.getItem(id: itemId)

            // Create PlayerView (SwiftUI) and wrap in UIHostingController
            let playerView = PlayerView(itemId: itemId, currentItem: item)
                .environment(client)

            let vc = UIHostingController(rootView: playerView)
            vc.modalPresentationStyle = .fullScreen
            vc.view.backgroundColor = .black
            self.hostingVC = vc

            guard let rootVC = self.topViewController() else {
                logger.error("No root view controller")
                self.hostingVC = nil
                return
            }

            rootVC.present(vc, animated: true)
            logger.info("Player presented for: \(item?.name ?? itemId)")

            // Monitor dismiss
            self.startDismissMonitor()
        }
    }

    // MARK: - Dismiss

    func dismiss() {
        hostingVC?.dismiss(animated: true) { [weak self] in
            self?.cleanup()
        }
    }

    private func startDismissMonitor() {
        dismissCheckTask?.cancel()
        dismissCheckTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard let self, let vc = self.hostingVC else { break }

                if vc.presentingViewController == nil && vc.view.window == nil {
                    self.cleanup()
                    break
                }
            }
        }
    }

    private func cleanup() {
        dismissCheckTask?.cancel()
        dismissCheckTask = nil
        hostingVC = nil
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
