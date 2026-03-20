import Foundation

/// Lightweight representation of a Jellyfin user account.
struct UserDTO: Codable, Identifiable, Hashable {
    /// Unique user identifier.
    let id: String
    /// Display name of the user.
    let name: String
    /// Server this user belongs to.
    let serverId: String
    /// Whether the user has a password set.
    let hasPassword: Bool
    /// Primary image tag for the user's avatar (used to construct image URL).
    let primaryImageTag: String?
    /// User access policy containing parental controls and permissions.
    let policy: UserPolicy?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case serverId = "ServerId"
        case hasPassword = "HasPassword"
        case primaryImageTag = "PrimaryImageTag"
        case policy = "Policy"
    }
}
