import SwiftUI

/// Pill-shaped "Skip Intro" / "Skip Recap" button that appears when playback
/// is within a media segment. Positioned at the bottom-right of the player.
struct SkipButton: View {

    let segment: MediaSegment
    let onSkip: () -> Void

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        Button(action: onSkip) {
            HStack(spacing: 8) {
                Image(systemName: "forward.fill")
                    .font(.callout)
                Text(segment.type.skipLabel)
                    .font(.callout)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                Color.white.opacity(isFocused ? 1.0 : 0.25),
                in: Capsule()
            )
            .foregroundStyle(isFocused ? Color.black : Color.white)
            .animation(.easeInOut(duration: 0.15), value: isFocused)
        }
        .buttonStyle(.plain)
        .shadow(color: Color.black.opacity(0.4), radius: 8, y: 4)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 20) {
            SkipButton(
                segment: MediaSegment(
                    id: "1",
                    itemId: "item1",
                    type: .intro,
                    startTicks: 0,
                    endTicks: 300_000_000
                ),
                onSkip: {}
            )
        }
    }
}
