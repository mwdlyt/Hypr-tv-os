import Foundation

/// Paginated response wrapper for Jellyfin item queries.
struct ItemsResponse: Codable {
    /// The page of items matching the query.
    let items: [MediaItemDTO]
    /// Total number of items available server-side (for pagination).
    let totalRecordCount: Int

    enum CodingKeys: String, CodingKey {
        case items = "Items"
        case totalRecordCount = "TotalRecordCount"
    }
}

/// Response from the /Items/{id}/PlaybackInfo endpoint containing available media sources.
struct PlaybackInfoResponse: Codable {
    /// Available media sources for the requested item.
    let mediaSources: [MediaSourceDTO]
    /// Server-assigned session identifier for playback progress reporting.
    let playSessionId: String?

    enum CodingKeys: String, CodingKey {
        case mediaSources = "MediaSources"
        case playSessionId = "PlaySessionId"
    }
}
