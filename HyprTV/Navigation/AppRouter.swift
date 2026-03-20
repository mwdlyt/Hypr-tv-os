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

    // MARK: - Navigation

    func navigate(to destination: Destination) {
        path.append(destination)
    }

    func goBack() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path = NavigationPath()
    }
}
