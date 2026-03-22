import SwiftUI

/// Netflix-style profile selection screen showing user avatars in a grid.
/// Displayed after connecting to a Jellyfin server, before authentication.
struct UserProfilePickerView: View {

    @Environment(JellyfinClient.self) private var jellyfinClient
    let viewModel: UserProfileViewModel
    let serverName: String
    let onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 48) {
                // Header
                VStack(spacing: 12) {
                    Text("Who's Watching?")
                        .font(.system(size: 48, weight: .bold))

                    Text(serverName)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                // Error banner
                if let error = viewModel.error {
                    errorBanner(message: error)
                }

                // User grid
                if viewModel.isLoading {
                    ProgressView("Loading profiles...")
                        .padding(.top, 60)
                } else if viewModel.publicUsers.isEmpty {
                    emptyState
                } else {
                    userGrid
                }

                // Back button
                Button {
                    onBack()
                } label: {
                    Text("Choose a Different Server")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 20)
            }
            .padding(.vertical, 60)
            .padding(.horizontal, 80)
            .frame(maxWidth: .infinity)
        }
        .task {
            if viewModel.publicUsers.isEmpty {
                await viewModel.loadPublicUsers()
            }
        }
        .alert("Enter Password", isPresented: alertBinding) {
            SecureField("Password", text: passwordBinding)
            Button("Sign In") {
                Task {
                    await viewModel.loginSelectedUser()
                }
            }
            Button("Cancel", role: .cancel) {
                viewModel.showPasswordPrompt = false
                viewModel.selectedUser = nil
            }
        } message: {
            if let user = viewModel.selectedUser {
                Text("Enter the password for \(user.name)")
            }
        }
    }

    // MARK: - User Grid

    private var userGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: 180, maximum: 220), spacing: 40)
            ],
            spacing: 40
        ) {
            ForEach(viewModel.publicUsers) { user in
                userProfileButton(user: user)
            }
        }
        .padding(.horizontal, 40)
    }

    private func userProfileButton(user: UserDTO) -> some View {
        Button {
            viewModel.selectUser(user)
        } label: {
            VStack(spacing: 16) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 150, height: 150)

                    if let avatarURL = viewModel.avatarURL(for: user) {
                        AsyncPosterImage(
                            url: avatarURL,
                            width: 150,
                            height: 150
                        )
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.gray)
                    }
                }
                .overlay(
                    Circle()
                        .stroke(.clear, lineWidth: 3)
                )

                // Name
                Text(user.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                // Password indicator
                if user.hasPassword {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isAuthenticating)
        .opacity(viewModel.isAuthenticating && viewModel.selectedUser?.id == user.id ? 0.6 : 1.0)
        .overlay {
            if viewModel.isAuthenticating && viewModel.selectedUser?.id == user.id {
                ProgressView()
            }
        }
    }

    // MARK: - Empty State

    @State private var manualUsername: String = ""
    @State private var manualPassword: String = ""
    @State private var isManualLoading: Bool = false

    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Sign In")
                .font(.title2)
                .fontWeight(.bold)

            Text("Enter your username and password to continue.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 16) {
                TextField("Username", text: $manualUsername)
                    .textContentType(.username)
                    .autocorrectionDisabled()
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .frame(maxWidth: 400)

                SecureField("Password", text: $manualPassword)
                    .textContentType(.password)
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .frame(maxWidth: 400)

                Button {
                    Task { await manualLogin() }
                } label: {
                    HStack {
                        if isManualLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text("Sign In")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: 400)
                    .padding(.vertical, 14)
                    .background(.blue, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(manualUsername.isEmpty || isManualLoading)
            }
            .padding(.top, 8)
        }
        .padding(.top, 40)
    }

    private func manualLogin() async {
        isManualLoading = true
        defer { isManualLoading = false }
        do {
            // Use authService.login() to save credentials to Keychain for session persistence
            try await viewModel.authService.login(username: manualUsername, password: manualPassword)
        } catch {
            viewModel.error = "Sign in failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Error Banner

    private func errorBanner(message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(message)
                .font(.callout)
                .multilineTextAlignment(.leading)
        }
        .padding(20)
        .frame(maxWidth: 600)
        .background(.red.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Bindings

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.showPasswordPrompt },
            set: { viewModel.showPasswordPrompt = $0 }
        )
    }

    private var passwordBinding: Binding<String> {
        Binding(
            get: { viewModel.password },
            set: { viewModel.password = $0 }
        )
    }
}
