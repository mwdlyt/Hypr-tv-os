import Foundation

enum TimeFormatter {

    /// The number of Jellyfin ticks in one second.
    /// One tick equals 100 nanoseconds, so there are 10,000,000 ticks per second.
    private static let ticksPerSecond: Int64 = 10_000_000

    // MARK: - Public API

    /// Formats Jellyfin ticks to a human-readable runtime string such as "1h 23m".
    /// Returns nil when the input is nil or zero.
    static func runtime(from ticks: Int64?) -> String? {
        guard let ticks, ticks > 0 else { return nil }

        let totalSeconds = Int(ticks / ticksPerSecond)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    /// Formats a number of seconds into a player-style timestamp.
    /// Returns "1:23:45" when hours are present, or "23:45" otherwise.
    static func playerTime(from seconds: Int) -> String {
        let clamped = max(0, seconds)
        let hours = clamped / 3600
        let minutes = (clamped % 3600) / 60
        let secs = clamped % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }

    /// Converts Jellyfin ticks to whole seconds.
    static func ticksToSeconds(_ ticks: Int64) -> Int {
        Int(ticks / ticksPerSecond)
    }

    /// Converts seconds to Jellyfin ticks.
    static func secondsToTicks(_ seconds: Int) -> Int64 {
        Int64(seconds) * ticksPerSecond
    }
}
