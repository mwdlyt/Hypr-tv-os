import Foundation
import Network
import Observation

/// Discovers Jellyfin servers on the local network via UDP broadcast.
///
/// Jellyfin servers listen on UDP port 7359 for the message "who is JellyfinServer?"
/// and respond with a JSON payload containing their address, name, and ID.
/// Discovery runs for 3 seconds before automatically stopping.
@Observable
final class ServerDiscovery {

    // MARK: - Public state

    /// Servers discovered during the most recent scan.
    var discoveredServers: [DiscoveredServer] = []
    /// Whether a discovery scan is currently in progress.
    var isSearching: Bool = false

    // MARK: - Types

    /// Lightweight model for a server discovered via UDP broadcast.
    struct DiscoveredServer: Identifiable, Hashable {
        let id: String
        let name: String
        let address: String
    }

    /// JSON shape returned by the Jellyfin UDP discovery response.
    private struct DiscoveryResponse: Codable {
        let Address: String
        let Id: String
        let Name: String
    }

    // MARK: - Private

    private static let broadcastPort: UInt16 = 7359
    private static let discoveryMessage = "who is JellyfinServer?"
    private static let timeoutSeconds: Double = 3.0

    private var connection: NWConnection?
    private var listener: NWListener?
    private var timeoutTask: Task<Void, Never>?

    // MARK: - Discovery

    /// Starts a UDP broadcast discovery scan.
    ///
    /// Clears previously discovered servers, sends the broadcast message,
    /// and listens for responses for up to 3 seconds.
    func startDiscovery() {
        stopDiscovery()
        discoveredServers = []
        isSearching = true

        // Create a UDP listener on a random port to receive responses.
        do {
            let params = NWParameters.udp
            params.allowLocalEndpointReuse = true
            listener = try NWListener(using: params)
        } catch {
            isSearching = false
            return
        }

        listener?.newConnectionHandler = { [weak self] incomingConnection in
            self?.handleIncomingConnection(incomingConnection)
        }
        listener?.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.sendBroadcast()
            case .failed, .cancelled:
                self.isSearching = false
            default:
                break
            }
        }
        listener?.start(queue: .main)

        // Auto-stop after timeout.
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.timeoutSeconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.stopDiscovery()
            }
        }
    }

    /// Stops any in-progress discovery scan and releases network resources.
    func stopDiscovery() {
        timeoutTask?.cancel()
        timeoutTask = nil
        connection?.cancel()
        connection = nil
        listener?.cancel()
        listener = nil
        isSearching = false
    }

    // MARK: - Private helpers

    /// Sends the "who is JellyfinServer?" UDP broadcast to the local network.
    private func sendBroadcast() {
        let host = NWEndpoint.Host("255.255.255.255")
        let port = NWEndpoint.Port(rawValue: Self.broadcastPort)!

        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true
        // Enable broadcast on the UDP socket.
        params.requiredInterfaceType = .wifi

        let connection = NWConnection(host: host, port: port, using: params)
        self.connection = connection

        connection.stateUpdateHandler = { [weak self] state in
            if case .ready = state {
                let data = Self.discoveryMessage.data(using: .utf8)!
                connection.send(content: data, completion: .contentProcessed { _ in
                    // Broadcast sent; responses arrive on the listener.
                    _ = self // prevent premature deallocation
                })
            }
        }
        connection.start(queue: .main)
    }

    /// Handles an incoming UDP connection (a server response).
    private func handleIncomingConnection(_ incomingConnection: NWConnection) {
        incomingConnection.stateUpdateHandler = { state in
            if case .ready = state {
                incomingConnection.receiveMessage { [weak self] data, _, _, _ in
                    guard let self, let data else { return }
                    self.parseDiscoveryResponse(data)
                    incomingConnection.cancel()
                }
            }
        }
        incomingConnection.start(queue: .main)
    }

    /// Parses a JSON discovery response and adds the server if not already discovered.
    private func parseDiscoveryResponse(_ data: Data) {
        guard let response = try? JSONDecoder().decode(DiscoveryResponse.self, from: data) else { return }

        let server = DiscoveredServer(
            id: response.Id,
            name: response.Name,
            address: response.Address
        )

        // Avoid duplicates.
        if !discoveredServers.contains(where: { $0.id == server.id }) {
            discoveredServers.append(server)
        }
    }
}
