import Foundation
import Observation

// MARK: - AuthService

/// High-level authentication coordinator that manages login, logout, and session restoration.
///
/// Wraps `JellyfinClient` for credential management and persists session data
/// securely in the keychain so users do not need to re-authenticate on every launch.
@Observable
final class AuthService {

    // MARK: - Public state

    /// The currently authenticated user, or nil if not logged in.
    var currentUser: UserDTO?

    /// Convenience accessor for authentication status.
    var isLoggedIn: Bool { currentUser != nil && client.isAuthenticated }

    // MARK: - Dependencies

    /// The underlying Jellyfin HTTP client.
    let client: JellyfinClient

    // MARK: - Init

    init(client: JellyfinClient) {
        self.client = client
    }

    // MARK: - Login

    /// Connects to a server, authenticates, and persists the session to the keychain.
    ///
    /// - Parameters:
    ///   - serverURL: Full URL of the Jellyfin server (e.g. http://192.168.1.100:8096).
    ///   - username: Jellyfin username.
    ///   - password: Jellyfin password (may be empty if the user has no password).
    func login(serverURL: URL, username: String, password: String) async throws {
        // Validate connectivity first.
        _ = try await client.connectToServer(url: serverURL)

        // Authenticate with credentials.
        try await login(username: username, password: password)
    }

    /// Authenticates against an already-connected server and persists credentials.
    ///
    /// Use this when the `JellyfinClient` is already connected (has a `baseURL`).
    func login(username: String, password: String) async throws {
        guard let serverURL = client.baseURL else {
            throw JellyfinError.noBaseURL
        }

        let response = try await client.authenticate(username: username, password: password)

        // Persist session to keychain for restoration on next launch.
        try KeychainService.save(serverURL.absoluteString, for: .serverURL)
        try KeychainService.save(response.accessToken, for: .accessToken)
        try KeychainService.save(response.user.id, for: .userId)

        currentUser = response.user
    }

    // MARK: - Logout

    /// Clears all local session data and keychain credentials.
    func logout() {
        KeychainService.deleteAll()
        client.clearSession()
        currentUser = nil
    }

    // MARK: - Session Restoration

    /// Attempts to restore a previous session from the keychain.
    ///
    /// Validates the restored credentials by fetching the user's libraries.
    /// If the server rejects the token (e.g. it expired), credentials are cleared.
    ///
    /// - Returns: `true` if the session was successfully restored, `false` otherwise.
    @discardableResult
    func restoreSession() async throws -> Bool {
        guard
            let urlString = KeychainService.get(.serverURL),
            let serverURL = URL(string: urlString),
            let accessToken = KeychainService.get(.accessToken),
            let userId = KeychainService.get(.userId)
        else {
            return false
        }

        // Hydrate the client with saved credentials.
        client.restoreSession(baseURL: serverURL, accessToken: accessToken, userId: userId)

        // Validate the token is still accepted by making a lightweight request.
        do {
            _ = try await client.getLibraries()
        } catch {
            // Token is invalid or server is unreachable; clear stale credentials.
            logout()
            return false
        }

        // Token is valid. Reconstruct a minimal UserDTO from stored data.
        currentUser = UserDTO(
            id: userId,
            name: "",
            serverId: "",
            hasPassword: true
        )
        return true
    }
}
