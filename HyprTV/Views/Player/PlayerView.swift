import SwiftUI
import AVKit

/// PlayerView acts as a loading/error screen while preparing playback.
/// Once the stream URL is ready, it hands off to PlayerLauncher which
/// presents AVPlayerViewController natively via UIKit modal.
struct PlayerView: View {

    let itemId: String

    @Environment(JellyfinClient.self) private var jellyfinClient
    @Environment(AppRouter.self) private var router
    @State private var viewModel: PlayerViewModel?
    @State private var currentItem: MediaItemDTO?
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var launched = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let loadError {
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
                .focusable()
            } else if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading media...")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .focusable()
            }
        }
        .onExitCommand {
            // Menu button on loading/error screens
            router.dismissPlayer()
        }
        .task {
            guard !launched else { return }
            await loadAndPlay()
        }
    }

    // MARK: - Load & Play

    private func loadAndPlay() async {
        let vm = PlayerViewModel(itemId: itemId, client: jellyfinClient)
        viewModel = vm

        do {
            // Fetch item details for metadata
            if let item = try? await jellyfinClient.getItem(id: itemId) {
                currentItem = item
            }

            let streamURL = try await vm.loadPlaybackInfo()

            // Create AVPlayer with the HLS URL
            let asset = AVURLAsset(url: streamURL)
            let playerItem = AVPlayerItem(asset: asset)
            let player = AVPlayer(playerItem: playerItem)

            // Seek to resume position if needed
            if let ticks = currentItem?.userData?.playbackPositionTicks, ticks > 0 {
                let seconds = Double(ticks) / 10_000_000.0
                await player.seek(to: CMTime(seconds: seconds, preferredTimescale: 1000))
            }

            launched = true
            isLoading = false

            // Present the native player via UIKit
            await PlayerLauncher.shared.present(
                player: player,
                title: currentItem?.name
            ) {
                // Called when player is dismissed (Menu button)
                Task { @MainActor in
                    await vm.reportStop()
                    router.dismissPlayer()
                }
            }

            // Report playback started to Jellyfin
            await vm.reportStart()

        } catch {
            loadError = error.localizedDescription
            isLoading = false
        }
    }
}
