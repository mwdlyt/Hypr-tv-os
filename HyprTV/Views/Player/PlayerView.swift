import SwiftUI
import AVKit

/// Triggers AVPlayerViewController presentation modally via fullScreenCover.
/// This is how tvOS expects video players to work — modal presentation gives us
/// native Siri Remote controls, proper Menu button behavior, and correct rendering.
struct PlayerView: View {

    let itemId: String

    @Environment(JellyfinClient.self) private var jellyfinClient
    @Environment(AppRouter.self) private var router
    @State private var avPlayer = AVPlayerWrapper()
    @State private var viewModel: PlayerViewModel?
    @State private var currentItem: MediaItemDTO?
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var showPlayer = false

    var body: some View {
        ZStack {
            // Transparent background — the real UI is the fullScreenCover
            Color.black.ignoresSafeArea()

            if let loadError {
                // Error state — focusable so remote works
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.yellow)
                    Text("Playback Error")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(loadError)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 500)
                    Button("Go Back") {
                        router.dismissPlayer()
                    }
                    .buttonStyle(.card)
                    .padding(.top, 10)
                }
            } else if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Preparing playback...")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onExitCommand {
            router.dismissPlayer()
        }
        .task {
            await loadAndPlay()
        }
        .fullScreenCover(isPresented: $showPlayer) {
            // When dismissed (Menu button), clean up
            Task { await viewModel?.reportStop() }
            avPlayer.stop()
            router.dismissPlayer()
        } content: {
            AVPlayerViewWrapper(player: avPlayer.player, onDone: {
                showPlayer = false
            })
            .ignoresSafeArea()
        }
    }

    // MARK: - Load & Play

    private func loadAndPlay() async {
        let vm = PlayerViewModel(itemId: itemId, client: jellyfinClient)
        viewModel = vm

        do {
            if let item = try? await jellyfinClient.getItem(id: itemId) {
                currentItem = item
            }

            let streamURL = try await vm.loadPlaybackInfo()

            // Set metadata
            avPlayer.mediaTitle = currentItem?.name ?? ""
            var parts: [String] = []
            if let year = currentItem?.productionYear { parts.append(String(year)) }
            if let rating = currentItem?.officialRating { parts.append(rating) }
            avPlayer.mediaSubtitle = parts.joined(separator: " · ")

            // Resume from saved position
            let resumeTicks = currentItem?.userData?.playbackPositionTicks ?? 0
            avPlayer.playURL(streamURL, startPositionTicks: resumeTicks)

            isLoading = false
            showPlayer = true

            await vm.reportStart()
            await vm.loadSegments()

            if let item = currentItem {
                await vm.loadNextEpisode(currentItem: item)
            }
        } catch {
            loadError = error.localizedDescription
            isLoading = false
        }
    }
}

/// Simple wrapper that creates and presents a native AVPlayerViewController.
/// This is the proper tvOS way — presented modally via fullScreenCover.
struct AVPlayerViewWrapper: UIViewControllerRepresentable {
    let player: AVPlayer
    var onDone: (() -> Void)?

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.player = player
        vc.showsPlaybackControls = true
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // Player is already set
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onDone: onDone)
    }

    class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        let onDone: (() -> Void)?

        init(onDone: (() -> Void)?) {
            self.onDone = onDone
        }

        func playerViewControllerShouldDismiss(_ playerViewController: AVPlayerViewController) -> Bool {
            return true
        }

        func playerViewControllerDidEndDismissalTransition(_ playerViewController: AVPlayerViewController) {
            onDone?()
        }
    }
}
