import Foundation

// MARK: - ServerConnectionViewModel

/// Manages the full server connection lifecycle: discovery, URL validation,
/// server handshake, and user authentication against a Jellyfin instance.
@Observable
final class ServerConnectionViewModel {

    // MARK: - Connection State

    enum ConnectionState: Equatable {
        case disconnected
        case connected
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

    /// Servers found via UDP broadcast on the local network.
    var discoveredServers: [ServerInfo] {
        serverDiscovery.discoveredServers
    }

    // MARK: - Dependencies

    private let client: JellyfinClient
    private let serverDiscovery: ServerDiscovery
    private let authService: AuthService

    // MARK: - Init

    init(client: JellyfinClient, serverDiscovery: ServerDiscovery, authService: AuthService) {
        self.client = client
        self.serverDiscovery = serverDiscovery
        self.authService = authService
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
    func selectDiscoveredServer(_ server: ServerInfo) {
        if let localAddress = server.localAddress {
            serverURL = localAddress
        }
        serverInfo = server
    }

    // MARK: - Connection

    /// Validates the URL, connects to the Jellyfin server, and retrieves public server info.
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
            connectionState = .connected
            UserDefaultsStore.set(url.absoluteString, for: .lastServerURL)
        } catch {
            self.error = "Could not reach server: \(error.localizedDescription)"
            connectionState = .disconnected
        }
    }

    // MARK: - Authentication

    /// Authenticates the user with the connected Jellyfin server.
    func login() async {
        guard connectionState == .connected else {
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
        } catch {
            self.error = "Authentication failed: \(error.localizedDescription)"
        }
    }

    /// Attempts to restore a previously authenticated session from the keychain.
    /// Silently returns on failure so the user can log in manually.
    func tryRestoreSession() async {
        guard let savedURL = UserDefaultsStore.string(for: .lastServerURL),
              let url = URL(string: savedURL) else {
            return
        }

        serverURL = savedURL
        isConnecting = true

        do {
            let info = try await client.connectToServer(url: url)
            serverInfo = info
            connectionState = .connected

            try await authService.restoreSession()
            connectionState = .authenticated
        } catch {
            // Session restoration is best-effort; drop back to disconnected state
            // so the user sees the login screen rather than a cryptic error.
            connectionState = serverInfo != nil ? .connected : .disconnected
        }

        isConnecting = false
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
