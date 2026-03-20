import SwiftUI

/// A focusable row representing a discovered Jellyfin server on the local network.
struct ServerRowView: View {

    let server: ServerInfo
    let onSelect: () -> Void

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                Image(systemName: "server.rack")
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(server.serverName)
                        .font(.headline)
                        .lineLimit(1)

                    HStack(spacing: 12) {
                        if let address = server.localAddress {
                            Label(address, systemImage: "network")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Text("v\(server.version)")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.body)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.card)
    }
}

// MARK: - Preview

#Preview {
    ServerRowView(
        server: ServerInfo(
            id: "abc",
            serverName: "Living Room Server",
            version: "10.8.13",
            localAddress: "http://192.168.1.100:8096"
        )
    ) {
        print("Selected")
    }
}
