import Foundation

// MARK: - PlayerViewModel

/// Manages video playback state, track selection, overlay visibility, and
/// Jellyfin playback progress reporting. Designed to be driven by a VLCKit
/// player delegate in the view layer.
@Observable
final class PlayerViewModel {

    // MARK: - Properties

    var isPlaying: Bool = false
    var currentTime: Int64 = 0
    var duration: Int64 = 0
    var isBuffering: Bool = false
    var showOverlay: Bool = true

    var audioTracks: [MediaStreamDTO] = []
    var subtitleTracks: [MediaStreamDTO] = []
    var selectedAudioTrack: MediaStreamDTO?
    var selectedSubtitleTrack: MediaStreamDTO?

    /// The primary video stream for the currently loaded media source.
    /// Drives the Info panel's resolution, codec, and bitrate display.
    var videoStream: MediaStreamDTO?
    /// The media source selected for playback. Used by the Info panel to
    /// surface container format, total bitrate, and file size.
    var mediaSource: MediaSourceDTO?

    var playSessionId: String?
    var error: String?

    // MARK: - Media Segments (Skip Intro/Outro/Recap)

    /// All segments for the current item.
    var segments: [MediaSegment] = []

    /// The segment the playback position is currently within, if any.
    var currentSegment: MediaSegment? {
        segments.first { segment in
            currentTime >= segment.startTicks && currentTime < segment.endTicks
        }
    }

    // MARK: - External Subtitles

    /// External subtitle streams that need to be loaded via URL.
    var externalSubtitleStreams: [MediaStreamDTO] = []

    // MARK: - Up Next (Netflix-style)

    /// The next episode to play, if available.
    var nextEpisode: MediaItemDTO?
    /// Whether the Up Next overlay is visible.
    var showUpNext: Bool = false
    /// Countdown seconds until auto-play (starts at 30).
    var upNextCountdown: Int = 30
    /// Whether the user dismissed the Up Next card (episode still finishes, then auto-plays).
    var upNextDismissed: Bool = false
    /// Threshold in ticks before end to trigger Up Next (90 seconds).
    private static let upNextThresholdTicks: Int64 = 90 * 10_000_000
    /// Whether Up Next has already been triggered for this playback.
    private var upNextTriggered: Bool = false
    /// Countdown timer task.
    private var countdownTask: Task<Void, Never>?

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

        // Collect external subtitle streams
        externalSubtitleStreams = subtitleTracks.filter { $0.isExternal == true }

        guard let streamURL = client.streamURL(
            itemId: itemId,
            mediaSourceId: source.id
        ) else {
            throw PlayerError.invalidStreamURL
        }

        return streamURL
    }

    /// Returns URLs for all external subtitle streams from Jellyfin.
    func externalSubtitleURLs() -> [(stream: MediaStreamDTO, url: URL)] {
        guard let mediaSourceId else { return [] }
        return externalSubtitleStreams.compactMap { stream in
            let format = stream.codec ?? "srt"
            guard let url = client.subtitleURL(
                itemId: itemId,
                mediaSourceId: mediaSourceId,
                streamIndex: stream.index,
                format: format
            ) else { return nil }
            return (stream: stream, url: url)
        }
    }

    /// Loads media segments (intro/outro/recap/preview) from the server.
    func loadSegments() async {
        do {
            segments = try await client.getMediaSegments(itemId: itemId)
        } catch {
            // Non-fatal: segments are optional
            segments = []
        }
    }

    /// Checks if the current playback position is within a segment.
    /// Call this on every time update.
    func checkSegmentOverlay() {
        // currentSegment is a computed property, so it auto-updates
        // The view layer reads currentSegment to decide whether to show SkipButton
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

    /// Selects an audio track.
    func selectAudioTrack(_ track: MediaStreamDTO?) {
        selectedAudioTrack = track
    }

    /// Selects a subtitle track. Pass nil to disable subtitles.
    func selectSubtitleTrack(_ track: MediaStreamDTO?) {
        selectedSubtitleTrack = track
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

    // MARK: - Up Next Logic

    /// Call this from the current item's metadata to pre-fetch the next episode.
    func loadNextEpisode(currentItem: MediaItemDTO) async {
        guard currentItem.type == .episode,
              let seriesId = currentItem.seriesId,
              let seasonId = currentItem.seasonId,
              let episodeIndex = currentItem.indexNumber else { return }

        do {
            nextEpisode = try await client.getNextEpisode(
                seriesId: seriesId,
                seasonId: seasonId,
                currentEpisodeIndex: episodeIndex - 1 // API is 0-indexed, Jellyfin episodes are 1-indexed
            )
        } catch {
            nextEpisode = nil
        }
    }

    /// Called every time playback position updates. Checks if we're in the
    /// "Up Next" zone (last 90 seconds of an episode).
    func checkUpNextTrigger() {
        guard nextEpisode != nil,
              !upNextTriggered,
              duration > 0,
              duration - currentTime <= Self.upNextThresholdTicks,
              duration - currentTime > 0 else { return }

        upNextTriggered = true
        showUpNext = true
        upNextCountdown = 30
        startCountdown()
    }

    /// User taps "Play Now" — immediately jump to next episode.
    func playNextNow() {
        countdownTask?.cancel()
        showUpNext = false
        // The view layer should observe this and load the next episode
    }

    /// User taps "Cancel" — dismiss the overlay, let current episode finish,
    /// then auto-advance when it ends.
    func dismissUpNext() {
        countdownTask?.cancel()
        showUpNext = false
        upNextDismissed = true
    }

    /// Called when the current episode finishes (progress reaches end).
    /// Returns true if we should auto-advance to next episode.
    var shouldAutoPlayNext: Bool {
        nextEpisode != nil
    }

    /// Resets Up Next state for a new episode.
    func resetUpNextState() {
        countdownTask?.cancel()
        showUpNext = false
        upNextDismissed = false
        upNextTriggered = false
        upNextCountdown = 30
        nextEpisode = nil
    }

    private func startCountdown() {
        countdownTask?.cancel()
        countdownTask = Task { [weak self] in
            while let self, self.upNextCountdown > 0, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self.upNextCountdown -= 1
            }
            guard !Task.isCancelled else { return }
            // Countdown hit 0 — auto-play next
            self?.playNextNow()
        }
    }

    // MARK: - Private Helpers

    private func populateTracks(from source: MediaSourceDTO) {
        mediaSource = source
        guard let streams = source.mediaStreams else { return }

        audioTracks = streams.filter { $0.type == .audio }
        subtitleTracks = streams.filter { $0.type == .subtitle }
        videoStream = streams.first(where: { $0.type == .video })

        // Select default tracks.
        if let defaultAudio = audioTracks.first(where: { $0.isDefault == true }) {
            selectedAudioTrack = defaultAudio
        } else {
            selectedAudioTrack = audioTracks.first
        }

        if let defaultSub = subtitleTracks.first(where: { $0.isDefault == true }) {
            selectedSubtitleTrack = defaultSub
        } else {
            selectedSubtitleTrack = nil
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
