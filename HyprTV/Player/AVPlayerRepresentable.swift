import SwiftUI
import AVKit

/// UIViewControllerRepresentable that hosts an AVPlayerViewController for tvOS.
/// Uses the native tvOS player chrome for best Siri Remote integration.
struct AVPlayerRepresentable: UIViewControllerRepresentable {

    let player: AVPlayer
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.player = player
        vc.showsPlaybackControls = true
        vc.allowsPictureInPicturePlayback = false
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
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

        func playerViewControllerShouldDismiss(_ playerViewController: AVPlayerViewController) -> Bool {
            true
        }

        func playerViewControllerDidEndDismissalTransition(_ playerViewController: AVPlayerViewController) {
            onDismiss()
        }
    }
}
