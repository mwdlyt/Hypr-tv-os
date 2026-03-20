import Foundation

// MARK: - MediaItemDTO

/// Core DTO that represents any Jellyfin library item: movies, series, seasons, episodes, music, and box sets.
struct MediaItemDTO: Codable, Identifiable, Hashable {
    /// Unique item identifier.
    let id: String
    /// Display name of the item.
    let name: String
    /// Sort-friendly name variant.
    let sortName: String?
    /// Plot summary or description.
    let overview: String?
    /// Discriminator for the kind of media this item represents.
    let type: ItemType
    /// Name of the parent series (episodes and seasons only).
    let seriesName: String?
    /// Identifier of the parent series.
    let seriesId: String?
    /// Identifier of the parent season (episodes only).
    let seasonId: String?
    /// Episode number within a season.
    let indexNumber: Int?
    /// Season number (episodes use this to indicate which season they belong to).
    let parentIndexNumber: Int?
    /// Year the item was originally released.
    let productionYear: Int?
    /// Aggregate community rating (e.g. 8.5 out of 10).
    let communityRating: Double?
    /// Content rating string such as "PG-13", "R", or "TV-MA".
    let officialRating: String?
    /// Runtime in Jellyfin ticks (1 tick = 100 nanoseconds, 10_000_000 ticks = 1 second).
    let runTimeTicks: Int64?
    /// ISO-8601 premiere / air date string.
    let premiereDate: String?
    /// Genre labels associated with this item.
    let genres: [String]?
    /// Studios that produced this item.
    let studios: [StudioDTO]?
    /// Cast and crew associated with this item.
    let people: [PersonDTO]?
    /// Available media sources for playback.
    let mediaSources: [MediaSourceDTO]?
    /// Audio, video, and subtitle streams contained in this item.
    let mediaStreams: [MediaStreamDTO]?
    /// Per-user playback state (watched, favorite, progress).
    let userData: UserDataDTO?
    /// Mapping of image type to tag string used for cache-busting image URLs.
    let imageTags: [String: String]?
    /// Backdrop image tags for fan art / background images.
    let backdropImageTags: [String]?
    /// External provider identifiers (e.g. "Imdb" -> "tt1234567", "Tmdb" -> "12345").
    let providerIds: [String: String]?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case sortName = "SortName"
        case overview = "Overview"
        case type = "Type"
        case seriesName = "SeriesName"
        case seriesId = "SeriesId"
        case seasonId = "SeasonId"
        case indexNumber = "IndexNumber"
        case parentIndexNumber = "ParentIndexNumber"
        case productionYear = "ProductionYear"
        case communityRating = "CommunityRating"
        case officialRating = "OfficialRating"
        case runTimeTicks = "RunTimeTicks"
        case premiereDate = "PremiereDate"
        case genres = "Genres"
        case studios = "Studios"
        case people = "People"
        case mediaSources = "MediaSources"
        case mediaStreams = "MediaStreams"
        case userData = "UserData"
        case imageTags = "ImageTags"
        case backdropImageTags = "BackdropImageTags"
        case providerIds = "ProviderIds"
    }

    /// Discriminator for Jellyfin item types.
    enum ItemType: String, Codable, Hashable {
        case movie = "Movie"
        case series = "Series"
        case season = "Season"
        case episode = "Episode"
        case audio = "Audio"
        case musicAlbum = "MusicAlbum"
        case boxSet = "BoxSet"
        case unknown

        /// Gracefully falls back to `.unknown` for unrecognized item types.
        init(from decoder: Decoder) throws {
            let value = try decoder.singleValueContainer().decode(String.self)
            self = ItemType(rawValue: value) ?? .unknown
        }
    }
}

// MARK: - StudioDTO

/// Studio or production company associated with a media item.
struct StudioDTO: Codable, Hashable {
    let name: String
    let id: String

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case id = "Id"
    }
}

// MARK: - PersonDTO

/// Cast or crew member associated with a media item.
struct PersonDTO: Codable, Hashable {
    let name: String
    let id: String
    /// Character name or role description (actors only).
    let role: String?
    /// Person type: "Actor", "Director", "Writer", etc.
    let type: String?

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case id = "Id"
        case role = "Role"
        case type = "Type"
    }
}

// MARK: - UserDataDTO

/// Per-user playback state for a media item.
struct UserDataDTO: Codable, Hashable {
    /// Current playback position in ticks.
    let playbackPositionTicks: Int64
    /// Number of times this item has been fully played.
    let playCount: Int
    /// Whether the user has favorited this item.
    let isFavorite: Bool
    /// Whether the item is marked as played/watched.
    let played: Bool
    /// Number of child items not yet played (series and seasons).
    let unplayedItemCount: Int?

    enum CodingKeys: String, CodingKey {
        case playbackPositionTicks = "PlaybackPositionTicks"
        case playCount = "PlayCount"
        case isFavorite = "IsFavorite"
        case played = "Played"
        case unplayedItemCount = "UnplayedItemCount"
    }
}

// MARK: - MediaSourceDTO

/// A single playback source for a media item (there may be multiple versions/qualities).
struct MediaSourceDTO: Codable, Hashable {
    let id: String
    let name: String?
    /// Filesystem path on the server (informational only).
    let path: String?
    /// Container format (e.g. "mkv", "mp4").
    let container: String?
    /// File size in bytes.
    let size: Int64?
    /// Overall bitrate in bits per second.
    let bitrate: Int?
    /// URL for direct stream playback (no transcoding).
    let directPlayUrl: String?
    /// URL for server-side transcoded stream.
    let transcodingUrl: String?
    /// Audio, video, and subtitle streams within this source.
    let mediaStreams: [MediaStreamDTO]?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case path = "Path"
        case container = "Container"
        case size = "Size"
        case bitrate = "Bitrate"
        case directPlayUrl = "DirectStreamUrl"
        case transcodingUrl = "TranscodingUrl"
        case mediaStreams = "MediaStreams"
    }
}

// MARK: - MediaStreamDTO

/// A single audio, video, or subtitle stream within a media source.
struct MediaStreamDTO: Codable, Hashable, Identifiable {
    var id: Int { index }
    /// Zero-based stream index.
    let index: Int
    /// Whether this is a video, audio, or subtitle stream.
    let type: StreamType
    /// Codec identifier (e.g. "h264", "aac", "srt").
    let codec: String?
    /// ISO 639 language code.
    let language: String?
    /// Human-readable stream label.
    let displayTitle: String?
    /// Optional custom title.
    let title: String?
    /// Whether this stream is selected by default.
    let isDefault: Bool?
    /// Whether this subtitle stream is forced (always shown).
    let isForced: Bool?
    /// Whether this stream is stored in an external file.
    let isExternal: Bool?
    /// Number of audio channels.
    let channels: Int?
    /// Stream bitrate in bits per second.
    let bitRate: Int?
    /// Video frame height in pixels.
    let height: Int?
    /// Video frame width in pixels.
    let width: Int?

    enum CodingKeys: String, CodingKey {
        case index = "Index"
        case type = "Type"
        case codec = "Codec"
        case language = "Language"
        case displayTitle = "DisplayTitle"
        case title = "Title"
        case isDefault = "IsDefault"
        case isForced = "IsForced"
        case isExternal = "IsExternal"
        case channels = "Channels"
        case bitRate = "BitRate"
        case height = "Height"
        case width = "Width"
    }

    /// Discriminator for the kind of media stream.
    enum StreamType: String, Codable, Hashable {
        case video = "Video"
        case audio = "Audio"
        case subtitle = "Subtitle"
        case unknown

        /// Gracefully falls back to `.unknown` for unrecognized stream types.
        init(from decoder: Decoder) throws {
            let value = try decoder.singleValueContainer().decode(String.self)
            self = StreamType(rawValue: value) ?? .unknown
        }
    }
}
