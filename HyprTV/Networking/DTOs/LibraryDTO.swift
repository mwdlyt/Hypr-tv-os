import Foundation

/// Represents a media library (view) such as Movies, TV Shows, or Music.
struct LibraryDTO: Codable, Identifiable, Hashable {
    /// Unique library identifier.
    let id: String
    /// Display name of the library.
    let name: String
    /// Collection type hint: "movies", "tvshows", "music", etc. Nil for mixed libraries.
    let collectionType: String?
    /// Primary image tag used to construct the library thumbnail URL.
    let imageTagsPrimary: String?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case collectionType = "CollectionType"
        case imageTags = "ImageTags"
    }

    /// Custom decoding to extract the nested "Primary" value from ImageTags.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        collectionType = try container.decodeIfPresent(String.self, forKey: .collectionType)

        let tags = try container.decodeIfPresent([String: String].self, forKey: .imageTags)
        imageTagsPrimary = tags?["Primary"]
    }

    /// Custom encoding that re-nests imageTagsPrimary back into ImageTags.Primary.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(collectionType, forKey: .collectionType)

        if let tag = imageTagsPrimary {
            try container.encode(["Primary": tag], forKey: .imageTags)
        }
    }

    /// Memberwise initializer for programmatic construction.
    init(id: String, name: String, collectionType: String?, imageTagsPrimary: String?) {
        self.id = id
        self.name = name
        self.collectionType = collectionType
        self.imageTagsPrimary = imageTagsPrimary
    }
}
