import Foundation
import UIKit

// MARK: - VLC Stub Types
// Lightweight stubs that mirror the VLCKit API surface used by VLCPlayerWrapper.
// These allow the project to compile and run in the tvOS Simulator without the
// VLCKit binary framework (which only supports real devices).

// MARK: - VLCMediaPlayerState

@objc enum VLCMediaPlayerState: Int {
    case stopped = 0
    case opening = 1
    case buffering = 2
    case playing = 3
    case paused = 4
    case error = 5
    case ended = 6
}

// MARK: - VLCTime

@objc class VLCTime: NSObject {
    private let _value: Int32

    @objc var intValue: Int32 { _value }

    @objc init(int value: Int32) {
        _value = value
        super.init()
    }

    override init() {
        _value = 0
        super.init()
    }
}

// MARK: - VLCMedia

@objc class VLCMedia: NSObject {
    let length = VLCTime(int: 0)

    @objc init?(url: URL) {
        super.init()
    }

    @objc func addOptions(_ options: [String: Any]) {
        // no-op
    }
}

// MARK: - VLCMediaPlayerDelegate

@objc protocol VLCMediaPlayerDelegate: AnyObject {
    @objc optional func mediaPlayerStateChanged(_ aNotification: Notification)
    @objc optional func mediaPlayerTimeChanged(_ aNotification: Notification)
}

// MARK: - VLCMediaPlayer

@objc class VLCMediaPlayer: NSObject {
    @objc weak var delegate: VLCMediaPlayerDelegate?
    @objc var drawable: UIView?
    @objc var media: VLCMedia?
    @objc var time: VLCTime = VLCTime()
    @objc var state: VLCMediaPlayerState = .stopped
    @objc var isPlaying: Bool = false
    @objc var canPause: Bool = false

    @objc var currentAudioTrackIndex: Int32 = -1
    @objc var currentVideoSubTitleIndex: Int32 = -1

    @objc var audioTrackIndexes: [Any]? { nil }
    @objc var audioTrackNames: [Any]? { nil }
    @objc var videoSubTitlesIndexes: [Any]? { nil }
    @objc var videoSubTitlesNames: [Any]? { nil }

    @objc func play() {
        // no-op stub
    }

    @objc func pause() {
        // no-op stub
    }

    @objc func stop() {
        // no-op stub
    }
}
