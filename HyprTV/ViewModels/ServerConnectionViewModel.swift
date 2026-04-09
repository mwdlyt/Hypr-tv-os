import Foundation

// MARK: - ServerConnectionViewModel

/// Manages the full server connection lifecycle: discovery, URL validation,
/// server handshake, profile selection, and user authentication against a Jellyfin instance.
@Observable
final class ServerConnectionViewModel {

    // MARK: - Connection State

    enum ConnectionState: Equatable {
        case disconnected
        case connected
        case profileSelection
        case authenticated
    }

    // MARK: - Properties

    var serverURL: String = ""
    var username: String = ""
    var password: String = ""
    var isConnecting: Bool = false
    var isAuthenticating: Bool = false
    var error: String?
    var serverInfo: ServerInfo?
    var connectionState: ConnectionState = .disconnected

    /// Saved servers for multi-server support.
    var savedServers: [SavedServer] = []

    /// Servers found via UDP broadcast on the local network.
    var discoveredServers: [ServerDiscovery.DiscoveredServer] {
        serverDiscovery.discoveredServers
    }

    /// View model for the profile picker screen.
    var profileViewModel: UserProfileViewModel?

    // MARK: - Dependencies

    private let client: JellyfinClient
    private let serverDiscovery: ServerDiscovery
    let authService: AuthService

    // MARK: - Init

    init(client: JellyfinClient, serverDiscovery: ServerDiscovery, authService: AuthService) {
        self.client = client
        self.serverDiscovery = serverDiscovery
        self.authService = authService
        self.savedServers = ServerStore.getServers()
    }

    // MARK: - Discovery

    /// Kicks off UDP broadcast discovery for Jellyfin servers on the local network.
    func discoverServers() {
        serverDiscovery.startDiscovery()
    }

    /// Stops the active UDP discovery scan.
    func stopDiscovery() {
        serverDiscovery.stopDiscovery()
    }

    /// Populates the server URL field from a server found via discovery.
    func selectDiscoveredServer(_ server: ServerDiscovery.DiscoveredServer) {
        serverURL = server.address
    }

    // MARK: - Saved Servers

    /// Reloads the list of saved servers from persistent storage.
    func refreshSavedServers() {
        savedServers = ServerStore.getServers()
    }

    /// Connects to a previously saved server.
    func connectToSavedServer(_ server: SavedServer) async {
        serverURL = server.url
        await connectToServer()
    }

    /// Removes a saved server.
    func removeSavedServer(_ server: SavedServer) {
        ServerStore.removeServer(id: server.id)
        refreshSavedServers()
    }

    // MARK: - Connection

    /// Validates the URL, connects to the Jellyfin server, and retrieves public server info.
    /// After successful connection, transitions to profile selection.
    func connectToServer() async {
        let trimmed = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            error = "Please enter a server address."
            return
        }

        guard let url = normalizedURL(from: trimmed) else {
            error = "Invalid server address. Please enter a valid URL (e.g. http://192.168.1.100:8096)."
            return
        }

        error = nil
        isConnecting = true
        defer { isConnecting = false }

        do {
            let info = try await client.connectToServer(url: url)
            serverInfo = info
            connectionState = .profileSelection
            UserDefaultsStore.set(url.absoluteString, for: .lastServerURL)

            // Save this server for multi-server support
            let savedServer = SavedServer(
                name: info.serverName,
                url: url.absoluteString
            )
            ServerStore.saveServer(savedServer)
            refreshSavedServers()

            // Create profile view model for the profile picker
            profileViewModel = UserProfileViewModel(client: client, authService: authService)
        } catch {
            self.error = "Could not reach server: \(error.localizedDescription)"
            connectionState = .disconnected
        }
    }

    // MARK: - Authentication (Manual Login Fallback)

    /// Authenticates the user with the connected Jellyfin server.
    /// Used as a fallback when there are no public users or when manual login is needed.
    func login() async {
        guard connectionState == .connected || connectionState == .profileSelection else {
            error = "Connect to a server before logging in."
            return
        }

        let trimmedUser = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUser.isEmpty else {
            error = "Please enter a username."
            return
        }

        error = nil
        isAuthenticating = true
        defer { isAuthenticating = false }

        do {
            try await authService.login(username: trimmedUser, password: password)
            connectionState = .authenticated
            // Touch the server in saved servers to update lastUsed
            if let url = client.baseURL?.absoluteString {
                ServerStore.touchServer(url: url)
            }
        } catch {
            self.error = "Authentication failed: \(error.localizedDescription)"
        }
    }

    /// Navigates back to the disconnected state for server selection.
    func goBackToServerSelection() {
        connectionState = .disconnected
        error = nil
        serverInfo = nil
        profileViewModel = nil
        username = ""
        password = ""
    }

    /// Attempts to restore a previously authenticated session from the keychain.
    /// Silently returns on failure so the user can log in manually.
    func tryRestoreSession() async {
        // Only try to restore if we actually have saved credentials in the
        // keychain. Otherwise we'd waste a network round-trip and end up in
        // an inconsistent `.authenticated` state with no token.
        guard KeychainService.get(.accessToken) != nil,
              KeychainService.get(.userId) != nil,
              let urlString = KeychainService.get(.serverURL),
              let url = URL(string: urlString) else {
            return
        }

        serverURL = urlString
        isConnecting = true
        defer { isConnecting = false }

        do {
            // `restoreSession` rehydrates the client from keychain and
            // validates the token by calling a lightweight endpoint.
            let restored = try await authService.restoreSession()
            if restored {
                connectionState = .authenticated
            } else {
                // Keychain values disappeared between the pre-check and the
                // call; fall back to the server handshake below.
                let info = try await client.connectToServer(url: url)
                serverInfo = info
                connectionState = .profileSelection
                profileViewModel = UserProfileViewModel(client: client, authService: authService)
            }
        } catch {
            // Session restoration is best-effort. If the server rejected the
            // token or is unreachable, wipe any stale credentials and surface
            // the server picker again.
            authService.logout()
            connectionState = .disconnected
            serverInfo = nil
            profileViewModel = nil
        }
    }

    // MARK: - Private Helpers

    /// Normalizes a raw user-entered string into a well-formed URL.
    /// Adds an `http://` scheme when missing and strips trailing slashes.
    private func normalizedURL(from raw: String) -> URL? {
        var candidate = raw

        // Add scheme if the user omitted it.
        if !candidate.lowercased().hasPrefix("http://") && !candidate.lowercased().hasPrefix("https://") {
            candidate = "http://\(candidate)"
        }

        // Strip trailing slashes so path construction downstream is consistent.
        while candidate.hasSuffix("/") {
            candidate.removeLast()
        }

        return URL(string: candidate)
    }
}
