import Foundation

/// Represents public server information returned by the Jellyfin /System/Info/Public endpoint.
struct ServerInfo: Codable, Identifiable, Hashable {
    /// Unique server identifier.
    let id: String
    /// Human-readable server name configured by the admin.
    let serverName: String
    /// Jellyfin server version string (e.g. "10.8.13").
    let version: String
    /// LAN address the server is reachable on, if available.
    let localAddress: String?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case serverName = "ServerName"
        case version = "Version"
        case localAddress = "LocalAddress"
    }
}
