import Foundation

// MARK: - PlayerViewModel

/// Manages video playback state, track selection, overlay visibility, and
/// Jellyfin playback progress reporting. Designed to be driven by a VLCKit
/// player delegate in the view layer.
@Observable
final class PlayerViewModel {

    // MARK: - Track Info

    struct TrackInfo: Identifiable, Hashable {
        let id: Int
        let index: Int
        let title: String
    }

    // MARK: - Properties

    var isPlaying: Bool = false
    var currentTime: Int64 = 0
    var duration: Int64 = 0
    var isBuffering: Bool = false
    var showOverlay: Bool = true

    var audioTracks: [TrackInfo] = []
    var subtitleTracks: [TrackInfo] = []
    var selectedAudioTrack: Int = -1
    var selectedSubtitleTrack: Int = -1

    var playSessionId: String?
    var error: String?

    // MARK: - Computed Properties

    /// Playback progress as a value from 0.0 to 1.0.
    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(Double(currentTime) / Double(duration), 0), 1)
    }

    /// Current position formatted as "H:MM:SS" or "M:SS".
    var currentTimeFormatted: String {
        Self.formatTicks(currentTime)
    }

    /// Total duration formatted as "H:MM:SS" or "M:SS".
    var durationFormatted: String {
        Self.formatTicks(duration)
    }

    /// Time remaining formatted as "-H:MM:SS" or "-M:SS".
    var remainingTimeFormatted: String {
        let remaining = max(duration - currentTime, 0)
        return "-\(Self.formatTicks(remaining))"
    }

    // MARK: - Dependencies

    let itemId: String
    private let client: JellyfinClient

    /// Identifier of the media source selected for playback.
    private var mediaSourceId: String?

    // MARK: - Overlay Timer

    private var overlayTask: Task<Void, Never>?
    private static let overlayTimeout: UInt64 = 5_000_000_000 // 5 seconds in nanoseconds

    // MARK: - Init

    init(itemId: String, client: JellyfinClient) {
        self.itemId = itemId
        self.client = client
    }

    // MARK: - Playback Info

    /// Fetches playback info from the server and returns the stream URL
    /// that the VLCKit player should open.
    @discardableResult
    func loadPlaybackInfo() async throws -> URL {
        let response = try await client.getPlaybackInfo(itemId: itemId)
        playSessionId = response.playSessionId

        guard let source = response.mediaSources.first else {
            throw PlayerError.noMediaSource
        }

        mediaSourceId = source.id
        populateTracks(from: source)

        guard let streamURL = client.streamURL(
            itemId: itemId,
            mediaSourceId: source.id
        ) else {
            throw PlayerError.invalidStreamURL
        }

        return streamURL
    }

    // MARK: - Playback Reporting

    /// Reports playback start to the Jellyfin server.
    func reportStart() async {
        do {
            try await client.reportPlaybackStart(
                itemId: itemId,
                mediaSourceId: mediaSourceId,
                playSessionId: playSessionId
            )
        } catch {
            // Reporting failures are non-fatal; log internally but do not
            // surface to the user.
        }
    }

    /// Reports current playback progress to the Jellyfin server.
    /// Call this periodically (e.g. every 10 seconds) from the player delegate.
    func reportProgress() async {
        do {
            try await client.reportPlaybackProgress(
                itemId: itemId,
                mediaSourceId: mediaSourceId,
                positionTicks: currentTime,
                isPaused: !isPlaying,
                playSessionId: playSessionId
            )
        } catch {
            // Non-fatal.
        }
    }

    /// Reports playback stopped to the Jellyfin server with the final position.
    func reportStop() async {
        do {
            try await client.reportPlaybackStopped(
                itemId: itemId,
                mediaSourceId: mediaSourceId,
                positionTicks: currentTime,
                playSessionId: playSessionId
            )
        } catch {
            // Non-fatal.
        }
    }

    // MARK: - Playback Controls

    /// Toggles between playing and paused states.
    func togglePlayPause() {
        isPlaying.toggle()
    }

    /// Seeks to a specific position in ticks. The view layer should apply
    /// this to the VLCKit player.
    func seek(to ticks: Int64) {
        currentTime = max(0, min(ticks, duration))
    }

    /// Selects an audio track by its stream index.
    func selectAudioTrack(index: Int) {
        selectedAudioTrack = index
    }

    /// Selects a subtitle track by its stream index. Pass -1 to disable subtitles.
    func selectSubtitleTrack(index: Int) {
        selectedSubtitleTrack = index
    }

    // MARK: - Overlay

    /// Toggles the transport overlay and starts an auto-hide timer.
    func toggleOverlay() {
        showOverlay.toggle()

        if showOverlay {
            scheduleOverlayHide()
        } else {
            cancelOverlayHide()
        }
    }

    /// Resets the auto-hide timer without toggling visibility. Call this
    /// on any user interaction while the overlay is visible.
    func resetOverlayTimer() {
        guard showOverlay else { return }
        scheduleOverlayHide()
    }

    // MARK: - Private Helpers

    private func populateTracks(from source: MediaSourceDTO) {
        guard let streams = source.mediaStreams else { return }

        audioTracks = streams
            .filter { $0.type == .audio }
            .enumerated()
            .map { offset, stream in
                TrackInfo(
                    id: stream.index,
                    index: stream.index,
                    title: stream.displayTitle ?? stream.language ?? "Track \(offset + 1)"
                )
            }

        subtitleTracks = streams
            .filter { $0.type == .subtitle }
            .enumerated()
            .map { offset, stream in
                TrackInfo(
                    id: stream.index,
                    index: stream.index,
                    title: stream.displayTitle ?? stream.language ?? "Subtitle \(offset + 1)"
                )
            }

        // Select default tracks.
        if let defaultAudio = streams.first(where: { $0.type == .audio && $0.isDefault == true }) {
            selectedAudioTrack = defaultAudio.index
        } else if let firstAudio = audioTracks.first {
            selectedAudioTrack = firstAudio.index
        }

        if let defaultSub = streams.first(where: { $0.type == .subtitle && $0.isDefault == true }) {
            selectedSubtitleTrack = defaultSub.index
        } else {
            selectedSubtitleTrack = -1
        }
    }

    private func scheduleOverlayHide() {
        overlayTask?.cancel()
        overlayTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.overlayTimeout)
            guard !Task.isCancelled else { return }
            self?.showOverlay = false
        }
    }

    private func cancelOverlayHide() {
        overlayTask?.cancel()
        overlayTask = nil
    }

    // MARK: - Tick Formatting

    /// Converts Jellyfin ticks (100ns units) to a human-readable time string.
    private static func formatTicks(_ ticks: Int64) -> String {
        let totalSeconds = Int(ticks / 10_000_000)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    // MARK: - Errors

    enum PlayerError: LocalizedError {
        case noMediaSource
        case invalidStreamURL

        var errorDescription: String? {
            switch self {
            case .noMediaSource:
                return "No playable media source found for this item."
            case .invalidStreamURL:
                return "Could not construct a valid stream URL."
            }
        }
    }
}
