import SwiftUI

/// Transport controls overlay for the video player.
/// Shows title, progress bar, time labels, and track selection.
/// Auto-hides after 5 seconds of inactivity.
struct PlayerOverlayView: View {

    let viewModel: PlayerViewModel
    var currentItem: MediaItemDTO?
    var onExternalSubtitleLoaded: ((URL) -> Void)?

    @State private var showAudioPicker = false
    @State private var showSubtitlePicker = false
    @State private var hideTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            // Gradient background for readability
            VStack {
                LinearGradient(
                    colors: [.black.opacity(0.8), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 200)

                Spacer()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 300)
            }
            .ignoresSafeArea()

            VStack {
                // MARK: Top Bar - Title
                topBar
                    .padding(.top, 40)
                    .padding(.horizontal, 60)

                Spacer()

                // MARK: Bottom Controls
                VStack(spacing: 20) {
                    // Progress Bar
                    progressBar
                        .padding(.horizontal, 60)

                    // Time Labels
                    HStack {
                        Text(viewModel.currentTimeFormatted)
                            .font(.callout)
                            .monospacedDigit()

                        Spacer()

                        Text(viewModel.durationFormatted)
                            .font(.callout)
                            .monospacedDigit()
                    }
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 60)

                    // Transport Controls
                    transportControls
                        .padding(.bottom, 40)
                }
            }
        }
        .foregroundStyle(.white)
        .onAppear {
            scheduleAutoHide()
        }
        .onChange(of: viewModel.showOverlay) { _, newValue in
            if newValue {
                scheduleAutoHide()
            }
        }
        .sheet(isPresented: $showAudioPicker) {
            AudioTrackPickerView(viewModel: viewModel)
        }
        .sheet(isPresented: $showSubtitlePicker) {
            SubtitlePickerView(viewModel: viewModel)
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if viewModel.isBuffering {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(.white)
                        Text("Buffering...")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }

            Spacer()
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track background
                RoundedRectangle(cornerRadius: 4)
                    .fill(.white.opacity(0.3))
                    .frame(height: 8)

                // Progress fill
                RoundedRectangle(cornerRadius: 4)
                    .fill(.blue)
                    .frame(
                        width: max(0, geometry.size.width * viewModel.progress),
                        height: 8
                    )

                // Scrubber head
                Circle()
                    .fill(.white)
                    .frame(width: 20, height: 20)
                    .shadow(color: .black.opacity(0.3), radius: 4)
                    .offset(x: max(0, geometry.size.width * viewModel.progress - 10))
            }
        }
        .frame(height: 20)
        .focusable()
    }

    // MARK: - Transport Controls

    private var transportControls: some View {
        HStack(spacing: 40) {
            // Seek backward
            Button {
                viewModel.seek(to: max(0, viewModel.currentTime - 15))
            } label: {
                Image(systemName: "gobackward.15")
                    .font(.title2)
            }
            .buttonStyle(.plain)

            // Play/Pause
            Button {
                viewModel.togglePlayPause()
            } label: {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 44))
            }
            .buttonStyle(.plain)

            // Seek forward
            Button {
                viewModel.seek(to: min(viewModel.duration, viewModel.currentTime + 30))
            } label: {
                Image(systemName: "goforward.30")
                    .font(.title2)
            }
            .buttonStyle(.plain)

            Spacer()
                .frame(width: 40)

            // Audio Track
            Button {
                showAudioPicker = true
            } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)

            // Subtitle Track
            Button {
                showSubtitlePicker = true
            } label: {
                Image(systemName: "captions.bubble.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 60)
    }

    // MARK: - Auto Hide

    private func scheduleAutoHide() {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if viewModel.showOverlay {
                    viewModel.toggleOverlay()
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        // PlayerOverlayView requires a real viewModel
    }
}
