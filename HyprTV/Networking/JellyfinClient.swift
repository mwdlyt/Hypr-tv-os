import Foundation
import Observation

// MARK: - JellyfinError

/// Domain errors surfaced by the Jellyfin networking layer.
enum JellyfinError: LocalizedError {
    /// The client has no base URL configured. Call `connectToServer` first.
    case noBaseURL
    /// The client is not authenticated. Call `authenticate` first.
    case notAuthenticated
    /// The server returned a non-2xx HTTP status code.
    case httpError(statusCode: Int, data: Data?)
    /// The response body could not be decoded into the expected type.
    case decodingError(underlying: Error)
    /// A network-level failure occurred.
    case networkError(underlying: Error)
    /// The constructed URL was invalid.
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .noBaseURL:
            return "No server URL configured. Please connect to a server first."
        case .notAuthenticated:
            return "Not authenticated. Please sign in first."
        case .httpError(let code, _):
            return "Server returned HTTP \(code)."
        case .decodingError(let error):
            return "Failed to decode server response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidURL:
            return "Failed to construct a valid URL for the request."
        }
    }
}

// MARK: - JellyfinClient

/// Central HTTP client for all Jellyfin API interactions.
///
/// Uses the Observation framework (@Observable) so SwiftUI views automatically
/// react to changes in authentication state. All public methods are async/throws
/// and safe to call from any actor context.
@Observable
final class JellyfinClient {

    // MARK: - Public state

    /// Base URL of the connected Jellyfin server.
    var baseURL: URL?
    /// Access token received after authentication.
    var accessToken: String?
    /// Authenticated user's identifier.
    var userId: String?
    /// The authenticated user's policy for parental controls.
    var userPolicy: UserPolicy?

    /// Convenience check for whether the client holds valid credentials.
    var isAuthenticated: Bool {
        baseURL != nil && accessToken != nil && userId != nil
    }

    // MARK: - Private

    /// Stable device identifier persisted across launches.
    private let deviceId: String
    /// Shared URL session with sensible timeout configuration.
    private let session: URLSession

    // MARK: - Constants

    private static let clientName = "Hypr TV"
    private static let deviceName = "Apple TV"
    private static let clientVersion = "0.1.0"

    // MARK: - Init

    init() {
        // Persist a stable device ID in UserDefaults so the server can track this device.
        let key = "hypr_tv_device_id"
        if let existing = UserDefaults.standard.string(forKey: key) {
            self.deviceId = existing
        } else {
            let newId = UUID().uuidString
            UserDefaults.standard.set(newId, forKey: key)
            self.deviceId = newId
        }

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        config.httpAdditionalHeaders = ["Accept": "application/json"]
        self.session = URLSession(configuration: config)
    }

    // MARK: - Authorization Header

    /// Builds the `X-Emby-Authorization` header value required by Jellyfin.
    private var authorizationHeader: String {
        var header = "MediaBrowser Client=\"\(Self.clientName)\""
        header += ", Device=\"\(Self.deviceName)\""
        header += ", DeviceId=\"\(deviceId)\""
        header += ", Version=\"\(Self.clientVersion)\""
        if let token = accessToken {
            header += ", Token=\"\(token)\""
        }
        return header
    }

    // MARK: - Generic Request

    /// Performs an HTTP request to the given endpoint, attaches auth headers, and decodes the response.
    private func request<T: Decodable>(_ endpoint: Endpoint, body: Data? = nil) async throws -> T {
        guard let baseURL else { throw JellyfinError.noBaseURL }

        let url = endpoint.url(baseURL: baseURL)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = endpoint.method
        urlRequest.setValue(authorizationHeader, forHTTPHeaderField: "X-Emby-Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body {
            urlRequest.httpBody = body
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw JellyfinError.networkError(underlying: error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw JellyfinError.networkError(underlying: URLError(.badServerResponse))
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw JellyfinError.httpError(statusCode: httpResponse.statusCode, data: data)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw JellyfinError.decodingError(underlying: error)
        }
    }

    /// Fire-and-forget request that ignores the response body (used for playback reporting, watch status, favorites).
    private func requestIgnoringResponse(_ endpoint: Endpoint, body: Data? = nil) async throws {
        guard let baseURL else { throw JellyfinError.noBaseURL }

        let url = endpoint.url(baseURL: baseURL)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = endpoint.method
        urlRequest.setValue(authorizationHeader, forHTTPHeaderField: "X-Emby-Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body {
            urlRequest.httpBody = body
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw JellyfinError.networkError(underlying: error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw JellyfinError.networkError(underlying: URLError(.badServerResponse))
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw JellyfinError.httpError(statusCode: httpResponse.statusCode, data: data)
        }
    }

    // MARK: - Server Connection

    /// Validates connectivity to a Jellyfin server and returns its public info.
    func connectToServer(url: URL) async throws -> ServerInfo {
        self.baseURL = url
        self.accessToken = nil
        self.userId = nil
        let info: ServerInfo = try await request(.publicServerInfo)
        return info
    }

    // MARK: - Public Users

    /// Fetches the list of public users from the connected server (no auth required).
    func fetchPublicUsers() async throws -> [UserDTO] {
        return try await request(.publicUsers)
    }

    // MARK: - Authentication

    /// Authenticates with username and password. Stores the resulting token and user ID.
    func authenticate(username: String, password: String) async throws -> AuthResponse {
        let body = try JSONEncoder().encode(["Username": username, "Pw": password])
        let response: AuthResponse = try await request(.authenticateByName, body: body)
        self.accessToken = response.accessToken
        self.userId = response.user.id
        return response
    }

    // MARK: - Libraries

    /// Fetches all media libraries (views) visible to the authenticated user.
    func getLibraries() async throws -> [LibraryDTO] {
        guard let userId else { throw JellyfinError.notAuthenticated }

        struct ViewsResponse: Codable {
            let items: [LibraryDTO]
            enum CodingKeys: String, CodingKey { case items = "Items" }
        }

        let response: ViewsResponse = try await request(.userViews(userId: userId))
        return response.items
    }

    // MARK: - Items

    /// Fetches the most recently added items, optionally filtered to a specific library.
    func getLatestItems(parentId: String? = nil, limit: Int = 16) async throws -> [MediaItemDTO] {
        guard let userId else { throw JellyfinError.notAuthenticated }
        return try await request(.latestItems(userId: userId, parentId: parentId, limit: limit))
    }

    /// Queries items with full pagination, filtering, and sorting support.
    func getItems(
        parentId: String? = nil,
        startIndex: Int = 0,
        limit: Int = 50,
        sortBy: String? = nil,
        sortOrder: String? = nil,
        includeItemTypes: String? = nil,
        recursive: Bool = true,
        maxOfficialRating: String? = nil,
        genreIds: String? = nil,
        officialRatings: String? = nil,
        nameStartsWith: String? = nil
    ) async throws -> ItemsResponse {
        guard let userId else { throw JellyfinError.notAuthenticated }
        return try await request(.items(
            userId: userId,
            parentId: parentId,
            startIndex: startIndex,
            limit: limit,
            sortBy: sortBy,
            sortOrder: sortOrder,
            includeItemTypes: includeItemTypes,
            recursive: recursive,
            maxOfficialRating: maxOfficialRating,
            genreIds: genreIds,
            officialRatings: officialRatings,
            nameStartsWith: nameStartsWith
        ))
    }

    /// Fetches full details for a single item.
    func getItem(id: String) async throws -> MediaItemDTO {
        guard let userId else { throw JellyfinError.notAuthenticated }
        return try await request(.item(userId: userId, itemId: id))
    }

    // MARK: - TV Shows

    /// Fetches all seasons for a given series.
    func getSeasons(seriesId: String) async throws -> [MediaItemDTO] {
        guard let userId else { throw JellyfinError.notAuthenticated }
        let response: ItemsResponse = try await request(.seasons(userId: userId, seriesId: seriesId))
        return response.items
    }

    /// Fetches all episodes within a specific season of a series.
    func getEpisodes(seriesId: String, seasonId: String) async throws -> [MediaItemDTO] {
        guard let userId else { throw JellyfinError.notAuthenticated }
        let response: ItemsResponse = try await request(.episodes(userId: userId, seriesId: seriesId, seasonId: seasonId))
        return response.items
    }

    /// Fetches the next episode after the given episode index in a season.
    func getNextEpisode(seriesId: String, seasonId: String, currentEpisodeIndex: Int) async throws -> MediaItemDTO? {
        guard let userId else { throw JellyfinError.notAuthenticated }
        let response: ItemsResponse = try await request(.nextEpisode(
            userId: userId,
            seriesId: seriesId,
            currentEpisodeIndex: currentEpisodeIndex,
            seasonId: seasonId
        ))
        // The API returns episodes starting from currentIndex. The next one is at index 1.
        return response.items.count > 1 ? response.items[1] : nil
    }

    // MARK: - Playback

    /// Retrieves available media sources and a play session ID for a given item.
    func getPlaybackInfo(itemId: String) async throws -> PlaybackInfoResponse {
        guard let userId else { throw JellyfinError.notAuthenticated }
        return try await request(.playbackInfo(userId: userId, itemId: itemId))
    }

    /// Notifies the server that playback has started.
    func reportPlaybackStart(itemId: String, mediaSourceId: String? = nil, playSessionId: String? = nil) async throws {
        var body: [String: Any] = ["ItemId": itemId]
        if let mediaSourceId { body["MediaSourceId"] = mediaSourceId }
        if let playSessionId { body["PlaySessionId"] = playSessionId }
        let data = try JSONSerialization.data(withJSONObject: body)
        try await requestIgnoringResponse(.reportPlaybackStart, body: data)
    }

    /// Reports the current playback position to the server.
    func reportPlaybackProgress(itemId: String, mediaSourceId: String? = nil, positionTicks: Int64, isPaused: Bool = false, playSessionId: String? = nil) async throws {
        var body: [String: Any] = [
            "ItemId": itemId,
            "PositionTicks": positionTicks,
            "IsPaused": isPaused
        ]
        if let mediaSourceId { body["MediaSourceId"] = mediaSourceId }
        if let playSessionId { body["PlaySessionId"] = playSessionId }
        let data = try JSONSerialization.data(withJSONObject: body)
        try await requestIgnoringResponse(.reportPlaybackProgress, body: data)
    }

    /// Notifies the server that playback has stopped at the given position.
    func reportPlaybackStopped(itemId: String, mediaSourceId: String? = nil, positionTicks: Int64, playSessionId: String? = nil) async throws {
        var body: [String: Any] = [
            "ItemId": itemId,
            "PositionTicks": positionTicks
        ]
        if let mediaSourceId { body["MediaSourceId"] = mediaSourceId }
        if let playSessionId { body["PlaySessionId"] = playSessionId }
        let data = try JSONSerialization.data(withJSONObject: body)
        try await requestIgnoringResponse(.reportPlaybackStopped, body: data)
    }

    // MARK: - Media Segments

    /// Fetches media segments (intro, outro, recap, preview) for a given item.
    func getMediaSegments(itemId: String) async throws -> [MediaSegment] {
        let response: MediaSegmentsResponse = try await request(.mediaSegments(itemId: itemId))
        return response.items
    }

    // MARK: - Subtitle URLs

    /// Constructs a URL for an external subtitle stream.
    ///
    /// - Parameters:
    ///   - itemId: The media item identifier.
    ///   - mediaSourceId: The media source identifier.
    ///   - streamIndex: The subtitle stream index.
    ///   - format: The subtitle format (e.g. "srt", "ass", "vtt").
    /// - Returns: A fully qualified subtitle URL with authentication, or nil if base URL is not set.
    func subtitleURL(itemId: String, mediaSourceId: String, streamIndex: Int, format: String) -> URL? {
        guard let baseURL, let token = accessToken else { return nil }

        let path = "/Videos/\(itemId)/\(mediaSourceId)/Subtitles/\(streamIndex)/Stream.\(format)"
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: token)
        ]
        return components?.url
    }

    // MARK: - Search

    /// Searches for movies, series, and episodes matching the given query string.
    /// Returns a full `ItemsResponse` so callers can paginate through large result sets.
    func search(query: String, startIndex: Int = 0, limit: Int = 50, maxOfficialRating: String? = nil) async throws -> ItemsResponse {
        guard let userId else { throw JellyfinError.notAuthenticated }
        return try await request(.search(userId: userId, searchTerm: query, startIndex: startIndex, limit: limit, maxOfficialRating: maxOfficialRating))
    }

    // MARK: - Resume

    /// Fetches items that the user has partially watched (continue watching).
    func getResumeItems(limit: Int = 12) async throws -> [MediaItemDTO] {
        guard let userId else { throw JellyfinError.notAuthenticated }
        let response: ItemsResponse = try await request(.resumeItems(userId: userId, limit: limit))
        return response.items
    }

    // MARK: - Similar Items

    /// Fetches items similar to the given item.
    func getSimilarItems(itemId: String, limit: Int = 12) async throws -> [MediaItemDTO] {
        guard let userId else { throw JellyfinError.notAuthenticated }
        let response: ItemsResponse = try await request(.similarItems(userId: userId, itemId: itemId, limit: limit))
        return response.items
    }

    // MARK: - Genres

    /// Fetches available genres, optionally scoped to a specific library.
    func getGenres(parentId: String? = nil) async throws -> [GenreDTO] {
        guard let userId else { throw JellyfinError.notAuthenticated }

        struct GenresResponse: Codable {
            let items: [GenreDTO]
            enum CodingKeys: String, CodingKey { case items = "Items" }
        }

        let response: GenresResponse = try await request(.genres(userId: userId, parentId: parentId))
        return response.items
    }

    // MARK: - Watch Status

    /// Marks an item as played/watched.
    func markPlayed(itemId: String) async throws {
        guard let userId else { throw JellyfinError.notAuthenticated }
        try await requestIgnoringResponse(.markPlayed(userId: userId, itemId: itemId))
    }

    /// Marks an item as unplayed/unwatched.
    func markUnplayed(itemId: String) async throws {
        guard let userId else { throw JellyfinError.notAuthenticated }
        try await requestIgnoringResponse(.markUnplayed(userId: userId, itemId: itemId))
    }

    // MARK: - Favorites

    /// Adds an item to the user's favorites.
    func favorite(itemId: String) async throws {
        guard let userId else { throw JellyfinError.notAuthenticated }
        try await requestIgnoringResponse(.favorite(userId: userId, itemId: itemId))
    }

    /// Removes an item from the user's favorites.
    func unfavorite(itemId: String) async throws {
        guard let userId else { throw JellyfinError.notAuthenticated }
        try await requestIgnoringResponse(.unfavorite(userId: userId, itemId: itemId))
    }

    // MARK: - Image URLs

    /// Constructs an image URL for the given item and image type.
    func imageURL(itemId: String, imageType: String = "Primary", maxWidth: Int? = nil, tag: String? = nil) -> URL? {
        guard let baseURL else { return nil }

        var components = URLComponents(url: baseURL.appendingPathComponent("/Items/\(itemId)/Images/\(imageType)"), resolvingAgainstBaseURL: false)
        var queryItems: [URLQueryItem] = []
        if let maxWidth {
            queryItems.append(URLQueryItem(name: "maxWidth", value: "\(maxWidth)"))
        }
        if let tag {
            queryItems.append(URLQueryItem(name: "tag", value: tag))
        }
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        return components?.url
    }

    /// Constructs a user profile image URL.
    func userImageURL(userId: String, tag: String? = nil, maxWidth: Int = 200) -> URL? {
        guard let baseURL else { return nil }
        var components = URLComponents(url: baseURL.appendingPathComponent("/Users/\(userId)/Images/Primary"), resolvingAgainstBaseURL: false)
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "maxWidth", value: "\(maxWidth)")
        ]
        if let tag {
            queryItems.append(URLQueryItem(name: "tag", value: tag))
        }
        components?.queryItems = queryItems
        return components?.url
    }

    /// Constructs a direct stream URL for playback with authentication baked in.
    /// Returns an HLS master playlist URL for the given item.
    /// Jellyfin will transcode if needed (MKV → HLS) or direct-stream compatible formats.
    func streamURL(itemId: String, mediaSourceId: String? = nil) -> URL? {
        guard let baseURL, let token = accessToken, let userId else { return nil }

        var components = URLComponents(url: baseURL.appendingPathComponent("/Videos/\(itemId)/master.m3u8"), resolvingAgainstBaseURL: false)
        var queryItems = [
            URLQueryItem(name: "api_key", value: token),
            URLQueryItem(name: "DeviceId", value: deviceId),
            URLQueryItem(name: "VideoCodec", value: "h264,hevc"),
            URLQueryItem(name: "AudioCodec", value: "aac,ac3,eac3"),
            URLQueryItem(name: "TranscodingMaxAudioChannels", value: "6"),
            URLQueryItem(name: "SegmentContainer", value: "ts"),
            URLQueryItem(name: "MinSegments", value: "1"),
            URLQueryItem(name: "BreakOnNonKeyFrames", value: "true"),
            URLQueryItem(name: "TranscodeReasons", value: "ContainerNotSupported"),
        ]
        if let mediaSourceId {
            queryItems.append(URLQueryItem(name: "MediaSourceId", value: mediaSourceId))
        }
        components?.queryItems = queryItems
        return components?.url
    }

    // MARK: - Session Restoration

    /// Restores a previously saved session without re-authenticating.
    func restoreSession(baseURL: URL, accessToken: String, userId: String) {
        self.baseURL = baseURL
        self.accessToken = accessToken
        self.userId = userId
    }

    /// Clears all session state, effectively logging out at the client level.
    func clearSession() {
        self.baseURL = nil
        self.accessToken = nil
        self.userId = nil
        self.userPolicy = nil
    }
}

// MARK: - PlaybackReporting Conformance

extension JellyfinClient: PlaybackReporting {
    func reportPlaybackStart(itemId: String, playSessionId: String?) async throws {
        try await reportPlaybackStart(itemId: itemId, mediaSourceId: nil, playSessionId: playSessionId)
    }

    func reportPlaybackProgress(itemId: String, playSessionId: String?, positionTicks: Int64, isPaused: Bool) async throws {
        try await reportPlaybackProgress(itemId: itemId, mediaSourceId: nil, positionTicks: positionTicks, isPaused: isPaused, playSessionId: playSessionId)
    }

    func reportPlaybackStopped(itemId: String, playSessionId: String?, positionTicks: Int64) async throws {
        try await reportPlaybackStopped(itemId: itemId, mediaSourceId: nil, positionTicks: positionTicks, playSessionId: playSessionId)
    }
}
