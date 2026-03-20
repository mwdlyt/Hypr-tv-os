import Foundation

/// Represents a Jellyfin user's access policy for parental controls and permissions.
struct UserPolicy: Codable, Hashable {
    /// Whether the user has administrator privileges.
    let isAdministrator: Bool
    /// Maximum allowed parental rating value. Nil means no restriction.
    let maxParentalRating: Int?
    /// Tags that are blocked for this user.
    let blockedTags: [String]?
    /// Whether the user can access all libraries.
    let enableAllFolders: Bool?
    /// Specific folder IDs the user is allowed to access (when enableAllFolders is false).
    let enabledFolders: [String]?

    enum CodingKeys: String, CodingKey {
        case isAdministrator = "IsAdministrator"
        case maxParentalRating = "MaxParentalRating"
        case blockedTags = "BlockedTags"
        case enableAllFolders = "EnableAllFolders"
        case enabledFolders = "EnabledFolders"
    }

    /// Known parental rating thresholds used by Jellyfin.
    /// These map content rating strings to numeric values for comparison.
    static let ratingValues: [String: Int] = [
        "G": 1,
        "PG": 5,
        "PG-13": 7,
        "R": 9,
        "NC-17": 10,
        "NR": 10,
        "TV-Y": 1,
        "TV-Y7": 3,
        "TV-G": 4,
        "TV-PG": 5,
        "TV-14": 7,
        "TV-MA": 9
    ]

    /// Returns the numeric value for a content rating string, or nil if unknown.
    static func numericValue(for rating: String) -> Int? {
        ratingValues[rating]
    }

    /// Checks whether a given content rating is allowed under this policy.
    func isRatingAllowed(_ officialRating: String?) -> Bool {
        guard let maxRating = maxParentalRating, maxRating > 0 else {
            return true
        }
        guard let rating = officialRating,
              let ratingValue = Self.numericValue(for: rating) else {
            // Unknown or missing ratings are allowed by default
            return true
        }
        return ratingValue <= maxRating
    }
}
