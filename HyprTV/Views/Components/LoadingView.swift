import SwiftUI

/// Centered loading indicator with an optional descriptive message.
struct LoadingView: View {

    var message: String?

    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            if let message {
                Text(message)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview {
    LoadingView(message: "Loading your library...")
}
