import SwiftUI

/// High-performance async image view backed by the multi-tier ImageLoader.
///
/// Unlike SwiftUI's built-in AsyncImage, this component:
/// - Uses a persistent disk cache so images survive app restarts
/// - Downsamples large artwork on decode to reduce memory pressure
/// - Deduplicates concurrent requests for the same URL
/// - Shows a smooth fade-in transition on first load
struct AsyncPosterImage: View {

    let url: URL?
    var width: CGFloat = Constants.Layout.posterWidth
    var height: CGFloat = Constants.Layout.posterHeight

    @State private var image: UIImage?
    @State private var didFail: Bool = false
    @State private var loadTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
                    .transition(.opacity.animation(.easeIn(duration: 0.2)))
            } else if didFail {
                placeholderView
                    .overlay {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
            } else {
                placeholderView
                    .overlay {
                        ProgressView()
                    }
            }
        }
        .frame(width: width, height: height)
        .cornerRadius(Constants.Layout.posterCornerRadius)
        .onAppear {
            guard image == nil, !didFail else { return }
            startLoading()
        }
        .onDisappear {
            loadTask?.cancel()
            loadTask = nil
        }
        .onChange(of: url) { _, newURL in
            image = nil
            didFail = false
            loadTask?.cancel()
            if newURL != nil {
                startLoading()
            }
        }
    }

    // MARK: - Loading

    private func startLoading() {
        guard let url else {
            didFail = true
            return
        }

        loadTask = Task {
            let loaded = await ImageLoader.shared.loadImage(from: url)
            guard !Task.isCancelled else { return }
            if let loaded {
                withAnimation(.easeIn(duration: 0.2)) {
                    image = loaded
                }
            } else {
                didFail = true
            }
        }
    }

    // MARK: - Placeholder

    private var placeholderView: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .frame(width: width, height: height)
            .overlay {
                Image(systemName: "film")
                    .font(.system(size: 32))
                    .foregroundStyle(.tertiary)
            }
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 20) {
        AsyncPosterImage(url: nil)
        AsyncPosterImage(url: URL(string: "https://example.com/invalid"))
    }
}
