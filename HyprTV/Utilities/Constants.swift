import Foundation
import CoreGraphics

enum Constants {

    static let clientName = "Hypr TV"
    static let clientVersion = "0.1.0"
    static let deviceName = "Apple TV"

    /// A persistent device identifier stored in UserDefaults.
    /// Generated once on first launch and reused for the lifetime of the app installation.
    static let deviceId: String = {
        let key = "device_unique_id"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let new = UUID().uuidString
        UserDefaults.standard.set(new, forKey: key)
        return new
    }()

    // MARK: - Image Sizing

    enum Images {
        static let posterMaxWidth = 400
        static let posterMaxHeight = 600
        static let backdropMaxWidth = 1920
        static let backdropQuality = 80
        static let thumbnailMaxWidth = 160
    }

    // MARK: - Layout

    enum Layout {
        static let posterWidth: CGFloat = 200
        static let posterHeight: CGFloat = 300
        static let posterCornerRadius: CGFloat = 12
        static let posterSpacing: CGFloat = 24
        static let rowSpacing: CGFloat = 50
        static let horizontalPadding: CGFloat = 60
        static let heroHeight: CGFloat = 700
    }

    // MARK: - Animation

    enum Animation {
        static let defaultDuration: Double = 0.3
        static let focusScaleFactor: CGFloat = 1.08
        static let heroCrossfadeDuration: Double = 0.6
    }

    // MARK: - Jellyfin Server Discovery

    enum Jellyfin {
        static let discoveryPort: UInt16 = 7359
        static let discoveryMessage = "who is JellyfinServer?"
        static let discoveryTimeout: TimeInterval = 3.0
    }
}
