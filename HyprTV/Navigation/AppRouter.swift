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

    /// Navigation path for the Home tab.
    var path = NavigationPath()

    /// Navigation path for the Search tab.
    var searchPath = NavigationPath()

    /// Tracks which tab is active to route navigation correctly.
    var activeTab: Tab = .home

    /// When set, a full-screen player overlay is presented (hides tab bar).
    var nowPlayingItemId: String?

    enum Tab {
        case home, search, settings
    }

    // MARK: - Navigation

    func navigate(to destination: Destination) {
        // Player gets special treatment — presented as full-screen overlay
        if case .player(let itemId) = destination {
            nowPlayingItemId = itemId
            return
        }
        // Push to whichever tab's navigation stack is active
        switch activeTab {
        case .search:
            searchPath.append(destination)
        default:
            path.append(destination)
        }
    }

    /// Dismisses the full-screen player overlay.
    func dismissPlayer() {
        nowPlayingItemId = nil
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
