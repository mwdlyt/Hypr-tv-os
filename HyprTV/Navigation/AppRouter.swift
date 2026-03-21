import SwiftUI

@Observable
final class AppRouter {

    // MARK: - Destinations

    enum Destination: Hashable {
        case home
        case library(LibraryDTO)
        case mediaDetail(itemId: String)
        case player(itemId: String)
        case search
        case settings
    }

    // MARK: - State

    var path = NavigationPath()

    /// When set, a full-screen player overlay is presented (hides tab bar).
    var nowPlayingItemId: String?

    // MARK: - Navigation

    func navigate(to destination: Destination) {
        // Player gets special treatment — presented as full-screen overlay
        if case .player(let itemId) = destination {
            nowPlayingItemId = itemId
            return
        }
        path.append(destination)
    }

    /// Dismisses the full-screen player overlay.
    func dismissPlayer() {
        nowPlayingItemId = nil
    }

    func goBack() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path = NavigationPath()
    }
}
