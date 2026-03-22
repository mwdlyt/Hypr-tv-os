import SwiftUI

/// Full-screen loading indicator. Focusable on tvOS so remote input works.
struct LoadingView: View {

    var message: String = "Loading..."

    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text(message)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .focusable()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
