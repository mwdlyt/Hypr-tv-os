import SwiftUI

/// A focusable row representing a discovered Jellyfin server on the local network.
struct ServerRowView: View {

    let server: ServerDiscovery.DiscoveredServer
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
                    Text(server.name)
                        .font(.headline)
                        .lineLimit(1)

                    Label(server.address, systemImage: "network")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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
        server: ServerDiscovery.DiscoveredServer(
            id: "abc",
            name: "Living Room Server",
            address: "http://192.168.1.100:8096"
        )
    ) {
        print("Selected")
    }
}
