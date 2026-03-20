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

        ScrollView {
            VStack(spacing: 48) {
                // MARK: Logo / Title
                headerView

                // MARK: Error Banner
                if let error = viewModel.error {
                    errorBanner(message: error)
                }

                // MARK: Server Connection or Login Form
                switch viewModel.connectionState {
                case .disconnected:
                    serverSelectionSection(viewModel: viewModel)
                case .connected:
                    loginSection(viewModel: viewModel)
                case .authenticated:
                    // Handled by RootView; show brief success state
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

    // MARK: - Server Selection

    @ViewBuilder
    private func serverSelectionSection(viewModel: ServerConnectionViewModel) -> some View {
        @Bindable var vm = viewModel

        VStack(spacing: 32) {
            // Discovered Servers
            if !viewModel.discoveredServers.isEmpty {
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

                dividerRow
            }

            // Manual Entry
            VStack(spacing: 20) {
                Text("Or Enter Server Address")
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
    }

    // MARK: - Login

    @ViewBuilder
    private func loginSection(viewModel: ServerConnectionViewModel) -> some View {
        @Bindable var vm = viewModel

        VStack(spacing: 32) {
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

            // Back to server selection
            Button {
                vm.connectionState = .disconnected
                vm.error = nil
            } label: {
                Text("Choose a Different Server")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
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
