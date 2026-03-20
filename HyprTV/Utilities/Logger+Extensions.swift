import os

extension Logger {

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.hypr.tv"

    /// Network requests, responses, and connectivity events.
    static let networking = Logger(subsystem: subsystem, category: "Networking")

    /// Media playback, buffering, and transport controls.
    static let player = Logger(subsystem: subsystem, category: "Player")

    /// View lifecycle, navigation, and layout events.
    static let ui = Logger(subsystem: subsystem, category: "UI")

    /// Authentication, token management, and session events.
    static let auth = Logger(subsystem: subsystem, category: "Auth")
}
