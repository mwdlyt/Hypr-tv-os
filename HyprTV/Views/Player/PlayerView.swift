import SwiftUI

/// Legacy PlayerView — playback is now handled entirely by PlayerLauncher (UIKit).
/// This view exists only as a NavigationStack destination fallback.
/// If you land here, something is wrong — player should launch via AppRouter.navigate(to: .player).
struct PlayerView: View {
    let itemId: String

    @Environment(JellyfinClient.self) private var jellyfinClient

    var body: some View {
        Color.black.ignoresSafeArea()
            .onAppear {
                // Redirect to UIKit player if we somehow end up here
                PlayerLauncher.shared.launch(itemId: itemId, client: jellyfinClient)
            }
    }
}
