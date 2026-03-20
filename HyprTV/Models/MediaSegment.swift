import Foundation

// MARK: - MediaSegment

/// Represents a timed segment within a media item, as detected by the
/// Jellyfin MediaSegments plugin (intros, outros, recaps, previews).
struct MediaSegment: Codable, Identifiable, Hashable {
    let id: String
    let itemId: String
    let type: SegmentType
    let startTicks: Int64
    let endTicks: Int64

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case itemId = "ItemId"
        case type = "Type"
        case startTicks = "StartTicks"
        case endTicks = "EndTicks"
    }

    /// The kind of segment detected.
    enum SegmentType: String, Codable, Hashable {
        case intro = "Intro"
        case outro = "Outro"
        case recap = "Recap"
        case preview = "Preview"
        case unknown

        init(from decoder: Decoder) throws {
            let value = try decoder.singleValueContainer().decode(String.self)
            self = SegmentType(rawValue: value) ?? .unknown
        }

        /// Display label shown on the skip button.
        var skipLabel: String {
            switch self {
            case .intro: return "Skip Intro"
            case .outro: return "Skip Outro"
            case .recap: return "Skip Recap"
            case .preview: return "Skip Preview"
            case .unknown: return "Skip"
            }
        }
    }
}

// MARK: - MediaSegmentsResponse

/// Response wrapper for the /MediaSegments endpoint.
struct MediaSegmentsResponse: Codable {
    let items: [MediaSegment]

    enum CodingKeys: String, CodingKey {
        case items = "Items"
    }
}
