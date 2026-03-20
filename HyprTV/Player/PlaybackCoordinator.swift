import Foundation
import os

// MARK: - PlaybackReporting

/// Protocol that abstracts the Jellyfin server calls needed by `PlaybackCoordinator`.
///
/// This decouples playback progress reporting from the concrete networking
/// client, making it easy to test and allowing the networking layer to be
/// built or swapped independently.
protocol PlaybackReporting: AnyObject {
    /// POST /Sessions/Playing
    func reportPlaybackStart(itemId: String, playSessionId: String?) async throws
    /// POST /Sessions/Playing/Progress
    func reportPlaybackProgress(itemId: String, playSessionId: String?, positionTicks: Int64, isPaused: Bool) async throws
    /// POST /Sessions/Playing/Stopped
    func reportPlaybackStopped(itemId: String, playSessionId: String?, positionTicks: Int64) async throws
}

// MARK: - PlaybackCoordinator

/// Coordinates playback lifecycle events with the Jellyfin server.
///
/// Responsibilities:
/// - Reports playback start so the server knows a session is active.
/// - Periodically reports progress (every 10 seconds) so the server can
///   update the "Continue Watching" position and display active sessions.
/// - Reports playback stopped so the server can finalise watch status.
///
/// All network calls are fire-and-forget from the UI perspective;
/// failures are logged but never surfaced as user-facing errors since
/// playback should not be interrupted by a reporting failure.
@Observable
final class PlaybackCoordinator {

    // MARK: - Properties

    private weak var client: (any PlaybackReporting)?
    private let itemId: String
    private(set) var playSessionId: String?

    private var reportingTask: Task<Void, Never>?
    private var hasReportedStart = false

    private let logger = Logger.player

    /// Interval between progress reports to the Jellyfin server.
    private let reportingInterval: TimeInterval = 10

    // MARK: - Initialisation

    /// Creates a coordinator for the given Jellyfin item.
    ///
    /// - Parameters:
    ///   - client: A type conforming to `PlaybackReporting` (typically the
    ///     Jellyfin networking client).
    ///   - itemId: The Jellyfin item ID being played.
    init(client: any PlaybackReporting, itemId: String) {
        self.client = client
        self.itemId = itemId
    }

    deinit {
        reportingTask?.cancel()
    }

    // MARK: - Public API

    /// Stores the play session identifier returned by the PlaybackInfo endpoint.
    func setPlaySessionId(_ id: String?) {
        playSessionId = id
    }

    /// Reports playback start to the Jellyfin server.
    /// Safe to call multiple times; only the first call sends the report.
    func reportStart() async {
        guard !hasReportedStart else { return }
        hasReportedStart = true

        do {
            try await client?.reportPlaybackStart(
                itemId: itemId,
                playSessionId: playSessionId
            )
            logger.info("PlaybackCoordinator: reported start for item \(self.itemId, privacy: .public)")
        } catch {
            logger.error("PlaybackCoordinator: failed to report start - \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Begins periodic progress reporting to the Jellyfin server.
    ///
    /// - Parameter positionProvider: A closure that returns the current
    ///   playback position in milliseconds. Called on each reporting cycle.
    /// - Parameter isPausedProvider: A closure that returns the current
    ///   paused state. Called on each reporting cycle.
    func startProgressReporting(
        positionProvider: @escaping @Sendable () -> Int64,
        isPausedProvider: @escaping @Sendable () -> Bool
    ) {
        stopReporting()

        reportingTask = Task { [weak self, itemId, playSessionId, reportingInterval] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(reportingInterval))

                guard !Task.isCancelled else { break }

                let positionMs = positionProvider()
                let isPaused = isPausedProvider()
                // Jellyfin uses ticks: 1 tick = 100 nanoseconds = 0.0001 ms
                // 1 ms = 10_000 ticks
                let positionTicks = positionMs * 10_000

                do {
                    try await self?.client?.reportPlaybackProgress(
                        itemId: itemId,
                        playSessionId: playSessionId,
                        positionTicks: positionTicks,
                        isPaused: isPaused
                    )
                } catch {
                    Logger.player.error("PlaybackCoordinator: progress report failed - \(error.localizedDescription, privacy: .public)")
                }
            }
        }

        logger.debug("PlaybackCoordinator: started progress reporting")
    }

    /// Reports playback stopped to the Jellyfin server.
    ///
    /// - Parameter positionTicks: Final playback position in Jellyfin ticks
    ///   (1 tick = 100 nanoseconds).
    func reportStop(positionTicks: Int64) async {
        stopReporting()

        guard hasReportedStart else { return }

        do {
            try await client?.reportPlaybackStopped(
                itemId: itemId,
                playSessionId: playSessionId,
                positionTicks: positionTicks
            )
            logger.info("PlaybackCoordinator: reported stop for item \(self.itemId, privacy: .public)")
        } catch {
            logger.error("PlaybackCoordinator: failed to report stop - \(error.localizedDescription, privacy: .public)")
        }

        hasReportedStart = false
    }

    /// Cancels the periodic progress reporting task.
    func stopReporting() {
        reportingTask?.cancel()
        reportingTask = nil
    }
}
