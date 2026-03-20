import SwiftUI

// MARK: - PlayerRepresentable

/// SwiftUI bridge that hosts `VLCPlayerViewController` inside a SwiftUI view
/// hierarchy on tvOS 17+.
///
/// Usage:
/// ```swift
/// PlayerRepresentable(playerWrapper: wrapper)
///     .ignoresSafeArea()
/// ```
struct PlayerRepresentable: UIViewControllerRepresentable {

    /// The shared player wrapper whose `videoView` will be displayed.
    let playerWrapper: VLCPlayerWrapper

    // MARK: - UIViewControllerRepresentable

    func makeUIViewController(context: Context) -> VLCPlayerViewController {
        VLCPlayerViewController(playerWrapper: playerWrapper)
    }

    func updateUIViewController(
        _ uiViewController: VLCPlayerViewController,
        context: Context
    ) {
        // No dynamic updates needed; the VLCPlayerWrapper drives state
        // changes through its @Observable properties.
    }
}
