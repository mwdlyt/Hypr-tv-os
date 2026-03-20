import SwiftUI

/// Full-screen setup flow for connecting to a Jellyfin server and authenticating.
/// Displayed when the user is not yet authenticated.
struct ServerConnectionView: View {

    @Environment(JellyfinClient.self) private var jellyfinClient
    @State private var viewModel: ServerConnectionViewModel?

    var body: some View {
        Group {
            if let viewModel {
                connectionContent(viewModel: viewModel)
            } else {
                LoadingView(message: "Initializing...")
            }
        }
        .task {
            if viewModel == nil {
                let vm = ServerConnectionViewModel(
                    client: jellyfinClient,
                    serverDiscovery: ServerDiscovery(),
                    authService: AuthService(client: jellyfinClient)
                )
                viewModel = vm
                await vm.tryRestoreSession()
                vm.discoverServers()
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func connectionContent(viewModel: ServerConnectionViewModel) -> some View {
        @Bindable var vm = viewModel

        switch viewModel.connectionState {
        case .disconnected:
            serverSelectionScreen(viewModel: viewModel)
        case .connected:
            // Brief transitional state — show login form
            loginScreen(viewModel: viewModel)
        case .profileSelection:
            if let profileVM = viewModel.profileViewModel {
                UserProfilePickerView(
                    viewModel: profileVM,
                    serverName: viewModel.serverInfo?.serverName ?? "Server",
                    onBack: {
                        viewModel.goBackToServerSelection()
                    }
                )
            } else {
                loginScreen(viewModel: viewModel)
            }
        case .authenticated:
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)
                Text("Connected")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
        }
    }

    // MARK: - Server Selection Screen

    @ViewBuilder
    private func serverSelectionScreen(viewModel: ServerConnectionViewModel) -> some View {
        @Bindable var vm = viewModel

        ScrollView {
            VStack(spacing: 48) {
                headerView

                if let error = viewModel.error {
                    errorBanner(message: error)
                }

                // Saved Servers
                if !viewModel.savedServers.isEmpty {
                    savedServersSection(viewModel: viewModel)
                    dividerRow
                }

                // Discovered Servers
                if !viewModel.discoveredServers.isEmpty {
                    discoveredServersSection(viewModel: viewModel)
                    dividerRow
                }

                // Manual Entry
                manualEntrySection(viewModel: viewModel)
            }
            .padding(.vertical, 60)
            .padding(.horizontal, 80)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Saved Servers Section

    @ViewBuilder
    private func savedServersSection(viewModel: ServerConnectionViewModel) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Servers")
                .font(.title3)
                .fontWeight(.semibold)

            ForEach(viewModel.savedServers) { server in
                HStack {
                    Button {
                        Task {
                            await viewModel.connectToSavedServer(server)
                        }
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "server.rack")
                                .font(.title2)
                                .foregroundStyle(.blue)
                                .frame(width: 44)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(server.name)
                                    .font(.headline)
                                Text(server.url)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                        .padding(16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.card)
                    .disabled(viewModel.isConnecting)

                    Button(role: .destructive) {
                        viewModel.removeSavedServer(server)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: 600)
    }

    // MARK: - Discovered Servers Section

    @ViewBuilder
    private func discoveredServersSection(viewModel: ServerConnectionViewModel) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Servers Found on Your Network")
                .font(.title3)
                .fontWeight(.semibold)

            ForEach(viewModel.discoveredServers) { server in
                ServerRowView(server: server) {
                    viewModel.selectDiscoveredServer(server)
                    Task {
                        await viewModel.connectToServer()
                    }
                }
            }
        }
        .frame(maxWidth: 600)
    }

    // MARK: - Manual Entry Section

    @ViewBuilder
    private func manualEntrySection(viewModel: ServerConnectionViewModel) -> some View {
        @Bindable var vm = viewModel

        VStack(spacing: 20) {
            Text("Enter Server Address")
                .font(.title3)
                .fontWeight(.semibold)

            TextField("Server URL (e.g. http://192.168.1.100:8096)", text: $vm.serverURL)
                .textContentType(.URL)
                .autocorrectionDisabled()
                .frame(maxWidth: 600)

            Button {
                Task {
                    await viewModel.connectToServer()
                }
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isConnecting {
                        ProgressView()
                    }
                    Text(viewModel.isConnecting ? "Connecting..." : "Connect")
                        .font(.headline)
                }
                .frame(minWidth: 200)
            }
            .disabled(viewModel.isConnecting || viewModel.serverURL.trimmingCharacters(in: .whitespaces).isEmpty)
            .buttonStyle(.card)
        }
    }

    // MARK: - Login Screen (Fallback)

    @ViewBuilder
    private func loginScreen(viewModel: ServerConnectionViewModel) -> some View {
        @Bindable var vm = viewModel

        ScrollView {
            VStack(spacing: 48) {
                headerView

                if let error = viewModel.error {
                    errorBanner(message: error)
                }

                // Server info confirmation
                if let info = viewModel.serverInfo {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Connected to \(info.serverName)")
                            .font(.headline)
                        Text("v\(info.version)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }

                VStack(spacing: 20) {
                    Text("Sign In")
                        .font(.title2)
                        .fontWeight(.semibold)

                    TextField("Username", text: $vm.username)
                        .textContentType(.username)
                        .autocorrectionDisabled()
                        .frame(maxWidth: 500)

                    SecureField("Password", text: $vm.password)
                        .textContentType(.password)
                        .frame(maxWidth: 500)

                    Button {
                        Task {
                            await viewModel.login()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if viewModel.isAuthenticating {
                                ProgressView()
                            }
                            Text(viewModel.isAuthenticating ? "Signing In..." : "Sign In")
                                .font(.headline)
                        }
                        .frame(minWidth: 200)
                    }
                    .disabled(viewModel.isAuthenticating || viewModel.username.trimmingCharacters(in: .whitespaces).isEmpty)
                    .buttonStyle(.card)
                }

                Button {
                    viewModel.goBackToServerSelection()
                } label: {
                    Text("Choose a Different Server")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 60)
            .padding(.horizontal, 80)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.blue)

            Text("Hypr TV")
                .font(.system(size: 56, weight: .bold))

            Text("Connect to your Jellyfin server")
                .font(.title3)
                .foregroundStyle(.secondary)
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

    // MARK: - Helpers

    private var dividerRow: some View {
        HStack {
            Rectangle()
                .fill(.quaternary)
                .frame(height: 1)
            Text("OR")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Rectangle()
                .fill(.quaternary)
                .frame(height: 1)
        }
        .frame(maxWidth: 600)
    }
}

// MARK: - Preview

#Preview {
    ServerConnectionView()
}
