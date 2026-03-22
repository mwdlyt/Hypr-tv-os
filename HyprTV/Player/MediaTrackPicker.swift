import SwiftUI

/// Data models for audio/subtitle track selection in the player.

struct AudioTrack: Identifiable, Hashable {
    let id: Int  // Jellyfin stream index
    let displayTitle: String
    let language: String?
    let codec: String?
    let channels: Int?
    let isDefault: Bool

    var label: String {
        // Clean up the display title — remove release group prefixes
        var title = displayTitle
        // Strip common prefixes like "BTM ", "FGT ", etc.
        let prefixes = ["BTM ", "FGT ", "GalaxyRG265 - ", "GalaxyRG - "]
        for prefix in prefixes {
            if title.hasPrefix(prefix) {
                title = String(title.dropFirst(prefix.count))
            }
        }
        return title
    }
}

struct SubtitleTrack: Identifiable, Hashable {
    let id: Int  // Jellyfin stream index
    let displayTitle: String
    let language: String?
    let codec: String?
    let isDefault: Bool
    let isForced: Bool
    let isExternal: Bool

    var label: String {
        var title = displayTitle
        let prefixes = ["BTM ", "FGT ", "BTM - "]
        for prefix in prefixes {
            if title.hasPrefix(prefix) {
                title = String(title.dropFirst(prefix.count))
            }
        }
        return title
    }
}

/// Extracts audio and subtitle tracks from Jellyfin media streams.
enum MediaTrackParser {
    static func audioTracks(from streams: [MediaStreamDTO]?) -> [AudioTrack] {
        guard let streams else { return [] }
        return streams
            .filter { $0.type == .audio }
            .map { stream in
                AudioTrack(
                    id: stream.index,
                    displayTitle: stream.displayTitle ?? "Audio \(stream.index)",
                    language: stream.language,
                    codec: stream.codec,
                    channels: stream.channels,
                    isDefault: stream.isDefault ?? false
                )
            }
    }

    static func subtitleTracks(from streams: [MediaStreamDTO]?) -> [SubtitleTrack] {
        guard let streams else { return [] }
        return streams
            .filter { $0.type == .subtitle }
            .map { stream in
                SubtitleTrack(
                    id: stream.index,
                    displayTitle: stream.displayTitle ?? "Subtitle \(stream.index)",
                    language: stream.language,
                    codec: stream.codec,
                    isDefault: stream.isDefault ?? false,
                    isForced: stream.isForced ?? false,
                    isExternal: stream.isExternal ?? false
                )
            }
    }
}
