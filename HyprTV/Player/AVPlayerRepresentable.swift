import SwiftUI
import AVKit

/// UIViewControllerRepresentable that hosts an AVPlayerViewController for tvOS.
/// Custom subclass handles Menu button to dismiss the player.
struct AVPlayerRepresentable: UIViewControllerRepresentable {

    let player: AVPlayer
    let title: String
    let subtitle: String
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> HyprPlayerViewController {
        let vc = HyprPlayerViewController()
        vc.player = player
        vc.showsPlaybackControls = true
        vc.allowsPictureInPicturePlayback = false
        vc.onMenuPressed = onDismiss
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: HyprPlayerViewController, context: Context) {
        uiViewController.player = player
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }

    class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        let onDismiss: () -> Void

        init(onDismiss: @escaping () -> Void) {
            self.onDismiss = onDismiss
        }

        // Called when the user swipes down to dismiss on tvOS
        func playerViewControllerShouldDismiss(_ playerViewController: AVPlayerViewController) -> Bool {
            return true
        }

        func playerViewControllerDidEndDismissalTransition(_ playerViewController: AVPlayerViewController) {
            onDismiss()
        }

        // Note: willEndFullScreenPresentation is unavailable on tvOS
        // Menu button handling is done in HyprPlayerViewController
    }
}

/// Custom AVPlayerViewController that intercepts Menu button.
/// On first menu press, native controls show/hide.
/// On menu press when controls are already hidden (or second press), we exit.
final class HyprPlayerViewController: AVPlayerViewController {

    var onMenuPressed: (() -> Void)?
    private var menuPressTime: Date = .distantPast

    override func viewDidLoad() {
        super.viewDidLoad()

        // Tap gesture for Menu button
        let menuTap = UITapGestureRecognizer(target: self, action: #selector(menuTapped))
        menuTap.allowedPressTypes = [NSNumber(value: UIPress.PressType.menu.rawValue)]
        view.addGestureRecognizer(menuTap)
    }

    @objc private func menuTapped() {
        let now = Date()
        let timeSinceLastPress = now.timeIntervalSince(menuPressTime)
        menuPressTime = now

        // If pressed twice within 1 second, or controls aren't showing — exit
        if timeSinceLastPress < 1.0 {
            onMenuPressed?()
        } else {
            // First press: let native AVPlayerViewController handle it (show/hide controls)
            // But set up so next press exits
            // Actually on tvOS, AVPlayerViewController shows controls on touch,
            // so menu should just exit since we added the gesture
            onMenuPressed?()
        }
    }
}
