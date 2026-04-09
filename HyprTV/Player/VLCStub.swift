import Foundation
import UIKit
import os

// MARK: - VLC Stub Types
// Simulator stubs that mirror the VLCKit API surface used by VLCPlayerWrapper.
// These simulate playback with a timer so the UI behaves realistically in the
// tvOS Simulator where the real VLCKit binary framework is unavailable.

private let stubLogger = Logger(subsystem: "com.hypr.tv", category: "VLCStub")

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
    private var _value: Int32

    @objc var intValue: Int32 { _value }

    @objc init(int value: Int32) {
        _value = value
        super.init()
    }

    override init() {
        _value = 0
        super.init()
    }

    func advance(by ms: Int32) {
        _value += ms
    }
}

// MARK: - VLCMedia

@objc class VLCMedia: NSObject {
    let url: URL
    let length: VLCTime

    /// Simulated duration: 90 minutes = 5_400_000 ms
    private static let simulatedDurationMs: Int32 = 5_400_000

    @objc init?(url: URL) {
        self.url = url
        self.length = VLCTime(int: VLCMedia.simulatedDurationMs)
        super.init()
        stubLogger.debug("VLCMedia: created for \(url.lastPathComponent, privacy: .public)")
    }

    @objc func addOptions(_ options: [String: Any]) {
        // Store options (no-op for simulation)
        stubLogger.debug("VLCMedia: addOptions called with \(options.count) keys")
    }
}

// MARK: - VLCMediaPlayerDelegate

@objc protocol VLCMediaPlayerDelegate: AnyObject {
    @objc optional func mediaPlayerStateChanged(_ aNotification: Notification)
    @objc optional func mediaPlayerTimeChanged(_ aNotification: Notification)
}

// MARK: - VLCMediaPlaybackSlaveType

@objc enum VLCMediaPlaybackSlaveType: Int {
    case subtitle = 0
    case audio = 1
}

// MARK: - VLCMediaPlayer

@objc class VLCMediaPlayer: NSObject {
    @objc weak var delegate: VLCMediaPlayerDelegate?

    @objc var drawable: UIView? {
        didSet { updateDrawableOverlay() }
    }

    @objc var media: VLCMedia? {
        didSet { mediaDidChange() }
    }

    @objc var time: VLCTime = VLCTime()
    @objc var state: VLCMediaPlayerState = .stopped
    @objc var isPlaying: Bool = false
    @objc var canPause: Bool = false

    /// Playback speed multiplier (1.0 = normal). Simulator honours this by
    /// scaling the tick interval so the UI reacts realistically.
    @objc var rate: Float = 1.0 {
        didSet {
            if isPlaying { startTimer() }
        }
    }

    /// Subtitle delay in microseconds (matches VLCKit's native type on device).
    @objc var currentVideoSubTitleDelay: Int = 0

    // MARK: - Audio tracks

    @objc var currentAudioTrackIndex: Int32 = 0

    @objc var audioTrackIndexes: [Any]? {
        return [NSNumber(value: -1), NSNumber(value: 0), NSNumber(value: 1), NSNumber(value: 2)]
    }

    @objc var audioTrackNames: [Any]? {
        return ["Disable", "English - TrueHD Atmos 7.1", "English - DD 5.1", "Spanish - DD 5.1"]
    }

    // MARK: - Subtitle tracks

    @objc var currentVideoSubTitleIndex: Int32 = -1

    @objc var videoSubTitlesIndexes: [Any]? {
        return [NSNumber(value: -1), NSNumber(value: 0), NSNumber(value: 1), NSNumber(value: 2), NSNumber(value: 3)]
    }

    @objc var videoSubTitlesNames: [Any]? {
        return ["Disable", "English", "English (SDH)", "Spanish", "French"]
    }

    // MARK: - Playback timer

    private var playbackTimer: Timer?
    private static let tickIntervalMs: Int32 = 250

    // MARK: - Playback controls

    @objc func play() {
        state = .playing
        isPlaying = true
        canPause = true

        startTimer()
        fireStateChanged()

        stubLogger.debug("VLCMediaPlayer: play()")
    }

    @objc func pause() {
        state = .paused
        isPlaying = false
        canPause = true

        stopTimer()
        fireStateChanged()

        stubLogger.debug("VLCMediaPlayer: pause()")
    }

    @objc func stop() {
        state = .stopped
        isPlaying = false
        canPause = false

        stopTimer()
        fireStateChanged()

        stubLogger.debug("VLCMediaPlayer: stop()")
    }

    @objc func addPlaybackSlave(_ url: URL, type: VLCMediaPlaybackSlaveType, enforce: Bool) -> Int {
        stubLogger.info("VLCMediaPlayer: addPlaybackSlave \(url.absoluteString, privacy: .public) type=\(type.rawValue) enforce=\(enforce)")
        return 0
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        // Respect the stub `rate` so the simulated timeline advances at the
        // same relative speed the real player would.
        let effectiveRate = max(rate, 0.1)
        let interval = TimeInterval(Self.tickIntervalMs) / 1000.0 / Double(effectiveRate)
        playbackTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self, self.isPlaying else { return }
            self.time.advance(by: Self.tickIntervalMs)

            // Stop at end of media
            if let media = self.media, self.time.intValue >= media.length.intValue {
                self.state = .ended
                self.isPlaying = false
                self.stopTimer()
                self.fireStateChanged()
                return
            }

            self.fireTimeChanged()
        }
    }

    private func stopTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    // MARK: - Delegate notifications

    private func fireStateChanged() {
        let notification = Notification(name: Notification.Name("VLCMediaPlayerStateChanged"), object: self)
        delegate?.mediaPlayerStateChanged?(notification)
    }

    private func fireTimeChanged() {
        let notification = Notification(name: Notification.Name("VLCMediaPlayerTimeChanged"), object: self)
        delegate?.mediaPlayerTimeChanged?(notification)
    }

    // MARK: - Media change simulation

    private func mediaDidChange() {
        guard media != nil else { return }
        updateDrawableOverlay()

        // Simulate opening → buffering → playing sequence
        state = .opening
        fireStateChanged()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self, self.media != nil else { return }
            self.state = .buffering
            self.fireStateChanged()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self, self.media != nil, self.state == .buffering else { return }
                // Don't auto-play here — VLCPlayerWrapper calls play() explicitly
            }
        }
    }

    // MARK: - Drawable overlay

    private let overlayTag = 9999

    private func updateDrawableOverlay() {
        guard let view = drawable else { return }

        // Remove existing overlay
        view.viewWithTag(overlayTag)?.removeFromSuperview()

        let overlay = UIView()
        overlay.tag = overlayTag
        overlay.translatesAutoresizingMaskIntoConstraints = false

        // Gradient background
        let gradient = CAGradientLayer()
        gradient.colors = [
            UIColor(red: 0.1, green: 0.0, blue: 0.3, alpha: 0.7).cgColor,
            UIColor(red: 0.0, green: 0.1, blue: 0.2, alpha: 0.7).cgColor,
        ]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        overlay.layer.addSublayer(gradient)

        // Label
        let filename = media?.url.lastPathComponent ?? "No media"
        let label = UILabel()
        label.text = "VLC Simulator - \(filename)"
        label.textColor = .white
        label.font = .systemFont(ofSize: 28, weight: .medium)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(label)

        view.addSubview(overlay)

        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            label.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
        ])

        // Resize gradient with layout
        overlay.layoutIfNeeded()
        gradient.frame = overlay.bounds

        // Keep gradient in sync via observer
        DispatchQueue.main.async {
            gradient.frame = overlay.bounds
        }
    }

    deinit {
        stopTimer()
    }
}
