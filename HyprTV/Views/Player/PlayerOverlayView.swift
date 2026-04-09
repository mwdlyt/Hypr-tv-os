import SwiftUI

/// Transport controls overlay for the VLC video player on tvOS.
/// Bottom-aligned layout: title → action buttons → progress bar → timestamps.
/// Auto-hides after 5 seconds of inactivity. Toggle with Siri Remote click.
///
/// Track switching, playback speed, and stream info all live in
/// `PlayerInfoPanel`, which the parent view summons via `onShowInfoPanel`.
struct PlayerOverlayView: View {

    let viewModel: PlayerViewModel
    let vlcWrapper: VLCPlayerWrapper
    var currentItem: MediaItemDTO?
    /// Asks the parent view to present the Audio / Subtitles / Speed / Info panel.
    var onShowInfoPanel: () -> Void

    @State private var isScrubbing = false
    @State private var scrubProgress: Double = 0

    @FocusState private var progressBarFocused: Bool

    var body: some View {
        ZStack {
            // Gradient overlays for readability
            gradients

            VStack(spacing: 0) {
                // Top: buffering indicator
                HStack {
                    if viewModel.isBuffering {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(.white)
                            Text("Buffering…")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .padding(.top, 50)
                        .padding(.leading, 60)
                    }
                    Spacer()
                }

                Spacer()

                // Bottom controls
                VStack(spacing: 16) {
                    // Title / subtitle
                    titleSection

                    // Action buttons
                    transportControls

                    // Progress bar
                    progressBar
                        .padding(.horizontal, 60)

                    // Time labels
                    HStack {
                        Text(isScrubbing ? scrubTimeFormatted : viewModel.currentTimeFormatted)
                            .font(.callout)
                            .monospacedDigit()
                        Spacer()
                        Text(viewModel.remainingTimeFormatted)
                            .font(.callout)
                            .monospacedDigit()
                    }
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 60)
                    .padding(.bottom, 50)
                }
            }
        }
        .foregroundStyle(.white)
    }

    // MARK: - Gradients

    private var gradients: some View {
        VStack {
            LinearGradient(
                colors: [.black.opacity(0.7), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 200)

            Spacer()

            LinearGradient(
                colors: [.clear, .black.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 350)
        }
        .ignoresSafeArea()
    }

    // MARK: - Title Section

    private var titleSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if let item = currentItem {
                    // Series info subtitle line
                    if item.type == .episode, let seriesName = item.seriesName {
                        Text(seriesName)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    // Main title
                    Text(titleText(for: item))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 60)
    }

    private func titleText(for item: MediaItemDTO) -> String {
        if item.type == .episode,
           let season = item.parentIndexNumber,
           let episode = item.indexNumber {
            return "S\(season):E\(episode) — \(item.name)"
        }
        return item.name
    }

    // MARK: - Transport Controls

    private var transportControls: some View {
        HStack(spacing: 40) {
            // Seek backward 15s
            Button {
                vlcWrapper.seekRelative(by: -15_000)
                viewModel.resetOverlayTimer()
            } label: {
                Image(systemName: "gobackward.15")
                    .font(.title2)
            }
            .buttonStyle(.plain)

            // Play / Pause
            Button {
                vlcWrapper.togglePlayPause()
                viewModel.resetOverlayTimer()
            } label: {
                Image(systemName: vlcWrapper.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 44))
            }
            .buttonStyle(.plain)

            // Seek forward 30s
            Button {
                vlcWrapper.seekRelative(by: 30_000)
                viewModel.resetOverlayTimer()
            } label: {
                Image(systemName: "goforward.30")
                    .font(.title2)
            }
            .buttonStyle(.plain)

            Spacer()
                .frame(width: 40)

            // Unified Audio / Subtitles / Info panel trigger. Mirrors the
            // gesture hint ("swipe down") so users discover both entry points.
            Button {
                onShowInfoPanel()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.title3)
                    Text("Audio & Subtitles")
                        .font(.callout)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(.white.opacity(0.18), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Swipe down on the remote to open this panel quickly")

            // Quick playback-speed indicator when not at 1×.
            if abs(vlcWrapper.playbackRate - 1.0) > 0.01 {
                Text(speedLabel)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white, in: Capsule())
            }
        }
        .padding(.horizontal, 60)
        .focusSection()
    }

    private var speedLabel: String {
        let rate = vlcWrapper.playbackRate
        if rate == rate.rounded() {
            return "\(Int(rate))×"
        }
        return String(format: "%.2g×", rate)
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geometry in
            let effectiveProgress = isScrubbing ? scrubProgress : viewModel.progress

            ZStack(alignment: .leading) {
                // Track background
                Capsule()
                    .fill(.white.opacity(0.3))
                    .frame(height: progressBarFocused ? 12 : 8)

                // Progress fill
                Capsule()
                    .fill(Color.blue)
                    .frame(
                        width: max(0, geometry.size.width * effectiveProgress),
                        height: progressBarFocused ? 12 : 8
                    )

                // Scrubber head (visible when focused)
                if progressBarFocused {
                    Circle()
                        .fill(.white)
                        .frame(width: 24, height: 24)
                        .shadow(color: .black.opacity(0.4), radius: 4)
                        .offset(x: max(0, min(geometry.size.width * effectiveProgress - 12, geometry.size.width - 24)))
                }
            }
            .animation(.easeInOut(duration: 0.15), value: progressBarFocused)
        }
        .frame(height: 24)
        .focusable()
        .focused($progressBarFocused)
        .onMoveCommand { direction in
            viewModel.resetOverlayTimer()

            // Scrub in ~10-second increments regardless of total runtime so
            // the user gets predictable jumps. For very short clips (< 10s)
            // we fall back to a 5% step.
            let durationMs = vlcWrapper.durationMs
            let stepFraction: Double
            if durationMs > 10_000 {
                stepFraction = 10_000.0 / Double(durationMs)
            } else {
                stepFraction = 0.05
            }

            switch direction {
            case .left:
                if !isScrubbing {
                    isScrubbing = true
                    scrubProgress = viewModel.progress
                }
                scrubProgress = max(0, scrubProgress - stepFraction)
            case .right:
                if !isScrubbing {
                    isScrubbing = true
                    scrubProgress = viewModel.progress
                }
                scrubProgress = min(1, scrubProgress + stepFraction)
            default:
                break
            }
        }
        .onExitCommand {
            // Commit scrub on menu press while scrubbing
            if isScrubbing {
                commitScrub()
            }
        }
        .onChange(of: progressBarFocused) { _, focused in
            if !focused && isScrubbing {
                commitScrub()
            }
        }
    }

    private func commitScrub() {
        guard isScrubbing else { return }
        let targetMs = Int64(scrubProgress * Double(vlcWrapper.durationMs))
        vlcWrapper.seek(to: targetMs)
        isScrubbing = false
    }

    private var scrubTimeFormatted: String {
        let totalSeconds = Int(scrubProgress * Double(vlcWrapper.durationMs) / 1000)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
    }
}
