import SwiftUI
import AVKit

/// UIViewControllerRepresentable that hosts an AVPlayerViewController for tvOS.
/// Handles Siri Remote Menu button to dismiss the player.
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

        // Set metadata for the native transport bar
        vc.title = title

        return vc
    }

    func updateUIViewController(_ uiViewController: HyprPlayerViewController, context: Context) {
        uiViewController.player = player
    }
}

/// Custom AVPlayerViewController subclass that intercepts the Menu button press.
/// When Menu is pressed while native controls are hidden, it dismisses the player.
final class HyprPlayerViewController: AVPlayerViewController {

    var onMenuPressed: (() -> Void)?
    private var menuPressCount = 0

    override func viewDidLoad() {
        super.viewDidLoad()

        // Add Menu button press recognizer
        let menuPress = UITapGestureRecognizer(target: self, action: #selector(handleMenuPress))
        menuPress.allowedPressTypes = [NSNumber(value: UIPress.PressType.menu.rawValue)]
        view.addGestureRecognizer(menuPress)
    }

    @objc private func handleMenuPress() {
        // First press hides native controls, second press exits
        // But since native AVPlayerVC handles first press, we just always exit
        onMenuPressed?()
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            if press.type == .menu {
                // If native controls are not visible, exit the player
                onMenuPressed?()
                return
            }
        }
        super.pressesBegan(presses, with: event)
    }
}
