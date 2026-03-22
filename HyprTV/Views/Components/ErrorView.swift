import SwiftUI

/// Displays an error message with an optional retry action.
/// Always focusable so tvOS remote can interact with it.
struct ErrorView: View {

    let message: String
    var retryAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.red)

            Text("Something Went Wrong")
                .font(.title2)
                .fontWeight(.semibold)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 500)

            if let retryAction {
                Button(action: retryAction) {
                    Label("Try Again", systemImage: "arrow.clockwise")
                        .font(.headline)
                }
                .buttonStyle(.card)
            }
        }
        .focusable()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
