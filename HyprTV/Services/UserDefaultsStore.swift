import Foundation

enum UserDefaultsStore {

    private static let defaults = UserDefaults.standard

    enum Key: String {
        case lastServerURL
        case lastUserId
        case preferredAudioLanguage
        case preferredSubtitleLanguage
        case subtitlesEnabled
        case audioOutputMode
        case audioBoostEnabled
        case audioBoostLevel
    }

    // MARK: - String

    static func string(for key: Key) -> String? {
        defaults.string(forKey: key.rawValue)
    }

    static func set(_ value: String?, for key: Key) {
        if let value {
            defaults.set(value, forKey: key.rawValue)
        } else {
            defaults.removeObject(forKey: key.rawValue)
        }
    }

    // MARK: - Bool

    static func bool(for key: Key) -> Bool {
        defaults.bool(forKey: key.rawValue)
    }

    static func set(_ value: Bool, for key: Key) {
        defaults.set(value, forKey: key.rawValue)
    }
}
