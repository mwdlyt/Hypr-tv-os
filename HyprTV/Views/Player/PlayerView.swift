import SwiftUI

/// Full-screen video player container.
/// Hosts the VLC player view controller and a transport controls overlay.
struct PlayerView: View {

    let itemId: String

    @Environment(JellyfinClient.self) private var jellyfinClient
    @State private var viewModel: PlayerViewModel?
    @State private var playerWrapper = VLCPlayerWrapper()

    var body: some View {
        ZStack {
            // Video layer
            Color.black
                .ignoresSafeArea()

            if let viewModel {
                // VLC player surface
                PlayerRepresentable(playerWrapper: playerWrapper)
                    .ignoresSafeArea()

                // Transport overlay
                PlayerOverlayView(viewModel: viewModel)
                    .opacity(viewModel.showOverlay ? 1 : 0)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.showOverlay)
            } else {
                LoadingView(message: "Preparing playback...")
            }
        }
        .onTapGesture {
            viewModel?.toggleOverlay()
        }
        .task {
            if viewModel == nil {
                let vm = PlayerViewModel(itemId: itemId, client: jellyfinClient)
                viewModel = vm
                do {
                    let streamURL = try await vm.loadPlaybackInfo()
                    playerWrapper.playURL(streamURL)
                    await vm.reportStart()
                } catch {
                    vm.error = "Failed to load playback info: \(error.localizedDescription)"
                }
            }
        }
        .onDisappear {
            Task {
                await viewModel?.reportStop()
            }
            playerWrapper.stop()
        }
        .navigationBarHidden(true)
        .persistentSystemOverlays(.hidden)
    }
}

// MARK: - Preview

#Preview {
    PlayerView(itemId: "test-item")
}
