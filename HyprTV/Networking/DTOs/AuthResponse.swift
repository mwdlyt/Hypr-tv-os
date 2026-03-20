import Foundation

/// Response returned by /Users/AuthenticateByName after a successful login.
struct AuthResponse: Codable {
    /// Bearer-style access token used for all subsequent API calls.
    let accessToken: String
    /// Identifier of the server that issued the token.
    let serverId: String
    /// Authenticated user profile.
    let user: UserDTO

    enum CodingKeys: String, CodingKey {
        case accessToken = "AccessToken"
        case serverId = "ServerId"
        case user = "User"
    }
}
