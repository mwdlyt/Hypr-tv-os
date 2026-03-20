import Foundation

/// A Jellyfin server that has been saved for quick reconnection.
struct SavedServer: Codable, Identifiable, Hashable {
    /// Unique identifier for this saved server entry.
    let id: String
    /// Display name of the server (from ServerInfo.serverName).
    let name: String
    /// Full URL of the server.
    let url: String
    /// Timestamp of the last successful connection.
    var lastUsed: Date

    init(id: String = UUID().uuidString, name: String, url: String, lastUsed: Date = Date()) {
        self.id = id
        self.name = name
        self.url = url
        self.lastUsed = lastUsed
    }
}
