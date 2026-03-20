import Foundation

/// Enum-based endpoint builder that maps every Jellyfin REST call to its path, HTTP method, and query parameters.
enum Endpoint {
    case publicServerInfo
    case authenticateByName
    case userViews(userId: String)
    case latestItems(userId: String, parentId: String?, limit: Int)
    case items(userId: String, parentId: String?, startIndex: Int, limit: Int,
               sortBy: String?, sortOrder: String?, includeItemTypes: String?, recursive: Bool)
    case item(userId: String, itemId: String)
    case seasons(userId: String, seriesId: String)
    case episodes(userId: String, seriesId: String, seasonId: String)
    case playbackInfo(userId: String, itemId: String)
    case reportPlaybackStart
    case reportPlaybackProgress
    case reportPlaybackStopped
    case search(userId: String, searchTerm: String, startIndex: Int, limit: Int)
    case resumeItems(userId: String, limit: Int)

    /// The URL path component (without base URL or query string).
    var path: String {
        switch self {
        case .publicServerInfo:
            return "/System/Info/Public"
        case .authenticateByName:
            return "/Users/AuthenticateByName"
        case .userViews(let userId):
            return "/Users/\(userId)/Views"
        case .latestItems(let userId, _, _):
            return "/Users/\(userId)/Items/Latest"
        case .items(let userId, _, _, _, _, _, _, _):
            return "/Users/\(userId)/Items"
        case .item(let userId, let itemId):
            return "/Users/\(userId)/Items/\(itemId)"
        case .seasons(_, let seriesId):
            return "/Shows/\(seriesId)/Seasons"
        case .episodes(_, let seriesId, _):
            return "/Shows/\(seriesId)/Episodes"
        case .playbackInfo(_, let itemId):
            return "/Items/\(itemId)/PlaybackInfo"
        case .reportPlaybackStart:
            return "/Sessions/Playing"
        case .reportPlaybackProgress:
            return "/Sessions/Playing/Progress"
        case .reportPlaybackStopped:
            return "/Sessions/Playing/Stopped"
        case .search(let userId, _, _, _):
            return "/Users/\(userId)/Items"
        case .resumeItems(let userId, _):
            return "/Users/\(userId)/Items/Resume"
        }
    }

    /// HTTP method for this endpoint.
    var method: String {
        switch self {
        case .authenticateByName,
             .playbackInfo,
             .reportPlaybackStart,
             .reportPlaybackProgress,
             .reportPlaybackStopped:
            return "POST"
        default:
            return "GET"
        }
    }

    /// Query parameters specific to this endpoint.
    private var queryItems: [URLQueryItem] {
        switch self {
        case .publicServerInfo, .authenticateByName,
             .userViews, .item,
             .reportPlaybackStart, .reportPlaybackProgress, .reportPlaybackStopped:
            return []

        case .latestItems(_, let parentId, let limit):
            var items = [URLQueryItem(name: "Limit", value: "\(limit)")]
            if let parentId {
                items.append(URLQueryItem(name: "ParentId", value: parentId))
            }
            items.append(URLQueryItem(name: "Fields", value: "Overview,PrimaryImageAspectRatio"))
            return items

        case .items(_, let parentId, let startIndex, let limit,
                    let sortBy, let sortOrder, let includeItemTypes, let recursive):
            var items: [URLQueryItem] = [
                URLQueryItem(name: "StartIndex", value: "\(startIndex)"),
                URLQueryItem(name: "Limit", value: "\(limit)"),
                URLQueryItem(name: "Recursive", value: "\(recursive)"),
                URLQueryItem(name: "Fields", value: "Overview,Genres,Studios,People,MediaSources,MediaStreams,UserData,PrimaryImageAspectRatio")
            ]
            if let parentId { items.append(URLQueryItem(name: "ParentId", value: parentId)) }
            if let sortBy { items.append(URLQueryItem(name: "SortBy", value: sortBy)) }
            if let sortOrder { items.append(URLQueryItem(name: "SortOrder", value: sortOrder)) }
            if let includeItemTypes { items.append(URLQueryItem(name: "IncludeItemTypes", value: includeItemTypes)) }
            return items

        case .seasons(let userId, _):
            return [
                URLQueryItem(name: "UserId", value: userId),
                URLQueryItem(name: "Fields", value: "Overview,UserData,PrimaryImageAspectRatio")
            ]

        case .episodes(let userId, _, let seasonId):
            return [
                URLQueryItem(name: "UserId", value: userId),
                URLQueryItem(name: "SeasonId", value: seasonId),
                URLQueryItem(name: "Fields", value: "Overview,MediaSources,MediaStreams,UserData,PrimaryImageAspectRatio")
            ]

        case .playbackInfo(let userId, _):
            return [
                URLQueryItem(name: "UserId", value: userId)
            ]

        case .search(_, let searchTerm, let startIndex, let limit):
            return [
                URLQueryItem(name: "SearchTerm", value: searchTerm),
                URLQueryItem(name: "StartIndex", value: "\(startIndex)"),
                URLQueryItem(name: "Limit", value: "\(limit)"),
                URLQueryItem(name: "Recursive", value: "true"),
                URLQueryItem(name: "IncludeItemTypes", value: "Movie,Series,Episode"),
                URLQueryItem(name: "Fields", value: "Overview,UserData,PrimaryImageAspectRatio")
            ]

        case .resumeItems(_, let limit):
            return [
                URLQueryItem(name: "Limit", value: "\(limit)"),
                URLQueryItem(name: "Recursive", value: "true"),
                URLQueryItem(name: "MediaTypes", value: "Video"),
                URLQueryItem(name: "Fields", value: "Overview,MediaSources,UserData,PrimaryImageAspectRatio")
            ]
        }
    }

    /// Constructs a fully qualified URL by combining the base URL, path, and query parameters.
    func url(baseURL: URL) -> URL {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            return baseURL.appendingPathComponent(path)
        }
        let items = queryItems
        if !items.isEmpty {
            components.queryItems = items
        }
        return components.url ?? baseURL.appendingPathComponent(path)
    }
}
