import Foundation

/// Manages the user profile selection screen after connecting to a Jellyfin server.
/// Fetches public users and handles authentication for the selected user.
@Observable
final class UserProfileViewModel {

    // MARK: - Properties

    var publicUsers: [UserDTO] = []
    var isLoading: Bool = false
    var isAuthenticating: Bool = false
    var error: String?

    /// The user currently being authenticated (for password prompt).
    var selectedUser: UserDTO?
    /// Password entered for password-protected users.
    var password: String = ""
    /// Whether the password prompt sheet is showing.
    var showPasswordPrompt: Bool = false

    // MARK: - Dependencies

    private let client: JellyfinClient
    private let authService: AuthService

    // MARK: - Init

    init(client: JellyfinClient, authService: AuthService) {
        self.client = client
        self.authService = authService
    }

    // MARK: - Public Methods

    /// Fetches public users from the connected server.
    func loadPublicUsers() async {
        isLoading = true
        error = nil

        do {
            publicUsers = try await client.fetchPublicUsers()
        } catch {
            self.error = "Failed to load users: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Called when the user taps a profile.
    /// If the user has no password, logs in immediately.
    /// If the user has a password, shows the password prompt.
    func selectUser(_ user: UserDTO) {
        selectedUser = user
        password = ""
        error = nil

        if user.hasPassword {
            showPasswordPrompt = true
        } else {
            Task {
                await loginSelectedUser()
            }
        }
    }

    /// Authenticates the selected user with the entered password.
    func loginSelectedUser() async {
        guard let user = selectedUser else { return }

        isAuthenticating = true
        error = nil

        do {
            try await authService.login(username: user.name, password: password)
            showPasswordPrompt = false
        } catch {
            self.error = "Login failed: \(error.localizedDescription)"
        }

        isAuthenticating = false
    }

    /// Returns the avatar image URL for a user.
    func avatarURL(for user: UserDTO) -> URL? {
        guard user.primaryImageTag != nil else { return nil }
        return client.userImageURL(userId: user.id, tag: user.primaryImageTag, maxWidth: 200)
    }
}
