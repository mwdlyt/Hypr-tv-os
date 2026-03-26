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
    var searchPath = NavigationPath()
    var activeTab: Tab = .home

    /// Reference to the Jellyfin client for player launches.
    var jellyfinClient: JellyfinClient?

    enum Tab {
        case home, search, settings
    }

    // MARK: - Navigation

    func navigate(to destination: Destination) {
        // Player launches via UIKit — no SwiftUI involvement
        if case .player(let itemId) = destination {
            playMedia(itemId: itemId)
            return
        }
        switch activeTab {
        case .search:
            searchPath.append(destination)
        default:
            path.append(destination)
        }
    }

    /// Launch media playback via VLCKit (UIKit modal presentation).
    func playMedia(itemId: String) {
        guard let client = jellyfinClient else { return }
        Task { @MainActor in
            PlayerLauncher.shared.launch(itemId: itemId, client: client)
        }
    }

    func goBack() {
        switch activeTab {
        case .search:
            guard !searchPath.isEmpty else { return }
            searchPath.removeLast()
        default:
            guard !path.isEmpty else { return }
            path.removeLast()
        }
    }

    func popToRoot() {
        switch activeTab {
        case .search:
            searchPath = NavigationPath()
        default:
            path = NavigationPath()
        }
    }
}
