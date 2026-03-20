import Foundation

/// Persists saved Jellyfin servers to UserDefaults for multi-server support.
enum ServerStore {

    private static let storageKey = "hypr_saved_servers"

    /// Returns all saved servers, sorted by most recently used first.
    static func getServers() -> [SavedServer] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return []
        }
        let servers = (try? JSONDecoder().decode([SavedServer].self, from: data)) ?? []
        return servers.sorted { $0.lastUsed > $1.lastUsed }
    }

    /// Saves a server, updating it if one with the same URL already exists.
    static func saveServer(_ server: SavedServer) {
        var servers = getServers()

        if let index = servers.firstIndex(where: { $0.url == server.url }) {
            servers[index] = server
        } else {
            servers.append(server)
        }

        persist(servers)
    }

    /// Updates the lastUsed timestamp for a server with the given URL.
    static func touchServer(url: String) {
        var servers = getServers()
        if let index = servers.firstIndex(where: { $0.url == url }) {
            servers[index].lastUsed = Date()
            persist(servers)
        }
    }

    /// Removes a saved server by its ID.
    static func removeServer(id: String) {
        var servers = getServers()
        servers.removeAll { $0.id == id }
        persist(servers)
    }

    /// Removes all saved servers.
    static func removeAll() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    private static func persist(_ servers: [SavedServer]) {
        if let data = try? JSONEncoder().encode(servers) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
