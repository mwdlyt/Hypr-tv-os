import Foundation
import UIKit
import AVFoundation
import os

// MARK: - VLCPlayerWrapper

/// Thread-safe wrapper around VLCMediaPlayer that exposes playback state
/// as @Observable properties for SwiftUI consumption on tvOS.
///
/// VLCMediaPlayer delegate callbacks arrive on an internal VLC thread.
/// Every mutation of published properties is dispatched to the main actor
/// so SwiftUI view updates are safe and predictable.
@Observable
final class VLCPlayerWrapper: NSObject {

    // MARK: - Observable State

    /// `true` while VLC reports the `.playing` state.
    var isPlaying = false
    /// `true` while VLC reports the `.paused` state.
    var isPaused = false
    /// `true` while VLC reports the `.buffering` state.
    var isBuffering = false
    /// `true` when VLC reports `.error`.
    var hasError = false
    /// Current playback position in milliseconds.
    var currentTimeMs: Int64 = 0
    /// Total duration in milliseconds. Updated once media metadata is parsed.
    var durationMs: Int64 = 0
    /// Normalised playback progress in 0...1 range, safe for progress bars.
    var progress: Double = 0

    /// Available audio tracks reported by VLC.
    var audioTracks: [(index: Int, title: String)] = []
    /// Available subtitle tracks reported by VLC.
    var subtitleTracks: [(index: Int, title: String)] = []
    /// Currently selected audio track index (-1 = disabled).
    var selectedAudioTrackIndex: Int = -1
    /// Currently selected subtitle track index (-1 = disabled).
    var selectedSubtitleTrackIndex: Int = -1

    /// Playback speed multiplier (1.0 = normal). Backed by `VLCMediaPlayer.rate`.
    var playbackRate: Float = 1.0
    /// Subtitle timing offset in seconds. Positive = subtitles later, negative = earlier.
    var subtitleDelaySeconds: Double = 0

    // MARK: - Video Surface

    /// The UIView that VLC renders video frames into.
    /// Attach this view to your view hierarchy before calling `playURL(_:)`.
    let videoView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.clipsToBounds = true
        return view
    }()

    // MARK: - Private

    private var mediaPlayer: VLCMediaPlayer?
    /// Guards against re-entrant setup calls.
    private var isSetUp = false

    /// Audio settings used for downmixing and format configuration.
    var audioSettings: AudioSettings?

    private let logger = Logger.player

    // MARK: - Lifecycle

    /// Creates the underlying `VLCMediaPlayer`, configures its delegate, and
    /// assigns the video drawable. Safe to call multiple times; subsequent
    /// calls are no-ops.
    func setup() {
        guard !isSetUp else { return }
        isSetUp = true

        let player = VLCMediaPlayer()
        player.delegate = self
        player.drawable = videoView
        mediaPlayer = player

        logger.debug("VLCPlayerWrapper: setup complete")
    }

    /// Tears down the player and releases resources.
    /// After calling this method the wrapper can be re-initialised via `setup()`.
    func cleanup() {
        stop()
        mediaPlayer?.delegate = nil
        mediaPlayer = nil
        isSetUp = false

        resetState()
        logger.debug("VLCPlayerWrapper: cleanup complete")
    }

    deinit {
        mediaPlayer?.delegate = nil
        mediaPlayer?.stop()
    }

    // MARK: - Playback Controls

    /// Loads the media at `url` and begins playback immediately.
    /// If the player has not been set up, `setup()` is called automatically.
    func playURL(_ url: URL) {
        if !isSetUp { setup() }
        guard let player = mediaPlayer else {
            logger.error("VLCPlayerWrapper: mediaPlayer is nil after setup")
            return
        }

        let media = VLCMedia(url: url)

        // Build comprehensive media options
        var options: [String: Any] = [:]

        // --- Network ---
        options["network-caching"] = 1500

        // --- Hardware-accelerated decoding ---
        options["--codec"] = "avcodec"
        options["--avcodec-hw"] = "any"

        // --- Video codecs: H.264, HEVC, VP9, AV1, MPEG-2, VC-1 ---
        options["--avcodec-skiploopfilter"] = 0  // full quality decoding

        // --- HDR passthrough ---
        options["--video-color-space"] = "auto"
        options["--video-transfer-function"] = "auto"

        // --- Subtitle rendering (SRT, ASS/SSA, PGS, DVDSUB, VobSub) ---
        options["--sub-autodetect-file"] = ""
        options["--sub-text-scale"] = 100
        options["--freetype-font"] = "Helvetica Neue"
        options["--freetype-fontsize"] = 24
        options["--freetype-color"] = 16777215  // white
        options["--freetype-rel-fontsize"] = 20
        options["--subsdec-encoding"] = "UTF-8"

        // --- Container / demuxer hints (MKV, MP4, AVI, MOV, WMV, FLV, TS, M2TS, ISO/BDMV) ---
        options["--adaptive-logic"] = "default"
        options["--live-caching"] = 1500
        options["--disc-caching"] = 1500

        // --- Audio codec support (DTS, DTS-HD MA, DTS-X, Dolby Digital/DD+, TrueHD, AAC, FLAC, PCM, MP3, Opus, Vorbis) ---
        options["--audio-desync"] = 0
        options["--audio-resampler"] = "soxr"

        // --- Audio downmixing from AudioSettings ---
        if let audioSettings {
            let audioOpts = audioSettings.vlcAudioOptions()
            for (key, value) in audioOpts {
                options[key] = value
            }

            // Preferred audio language
            if !audioSettings.preferredAudioLanguage.isEmpty {
                options["--audio-language"] = audioSettings.preferredAudioLanguage
            }

            // Preferred subtitle language
            if audioSettings.preferredSubtitleLanguage != "off" {
                options["--sub-language"] = audioSettings.preferredSubtitleLanguage
            }

            logger.info("VLCPlayerWrapper: audio mode = \(audioSettings.effectiveOutputMode.displayName)")
        }

        media?.addOptions(options)

        player.media = media
        player.play()

        logger.info("VLCPlayerWrapper: playing URL \(url.absoluteString, privacy: .public)")
    }

    /// Resumes playback if paused.
    func play() {
        guard let player = mediaPlayer else { return }
        if !player.isPlaying {
            player.play()
        }
    }

    /// Pauses playback.
    func pause() {
        guard let player = mediaPlayer else { return }
        if player.canPause {
            player.pause()
        }
    }

    /// Toggles between play and pause states.
    func togglePlayPause() {
        guard let player = mediaPlayer else { return }
        if player.isPlaying {
            pause()
        } else {
            play()
        }
    }

    /// Seeks to an absolute position in milliseconds.
    func seek(to positionMs: Int64) {
        guard let player = mediaPlayer else { return }
        let clamped = max(0, positionMs)
        let time = VLCTime(int: Int32(min(clamped, Int64(Int32.max))))
        player.time = time
        logger.debug("VLCPlayerWrapper: seek to \(clamped)ms")
    }

    /// Seeks forward or backward by `offsetMs` milliseconds relative to the current position.
    func seekRelative(by offsetMs: Int64) {
        let target = currentTimeMs + offsetMs
        let clampedTarget = max(0, min(target, durationMs))
        seek(to: clampedTarget)
    }

    /// Selects an audio track by its VLC index.
    func setAudioTrack(index: Int) {
        guard let player = mediaPlayer else { return }
        player.currentAudioTrackIndex = Int32(index)
        selectedAudioTrackIndex = index
        logger.debug("VLCPlayerWrapper: audio track set to \(index)")
    }

    /// Selects a subtitle track by its VLC index. Pass -1 to disable subtitles.
    func setSubtitleTrack(index: Int) {
        guard let player = mediaPlayer else { return }
        player.currentVideoSubTitleIndex = Int32(index)
        selectedSubtitleTrackIndex = index
        logger.debug("VLCPlayerWrapper: subtitle track set to \(index)")
    }

    /// Sets the playback speed multiplier. 1.0 is normal, 0.5 is half, 2.0 is double.
    /// Safe to call during playback — VLC retimes audio pitch automatically.
    func setPlaybackRate(_ rate: Float) {
        guard let player = mediaPlayer else { return }
        let clamped = max(0.25, min(rate, 4.0))
        player.rate = clamped
        playbackRate = clamped
        logger.debug("VLCPlayerWrapper: playback rate set to \(clamped)")
    }

    /// Shifts subtitle timing by `seconds`. Positive values push subtitles later.
    /// VLC's API is in microseconds as `Int`, so we convert here.
    func setSubtitleDelay(seconds: Double) {
        guard let player = mediaPlayer else { return }
        let micros = Int(seconds * 1_000_000)
        player.currentVideoSubTitleDelay = micros
        subtitleDelaySeconds = seconds
        logger.debug("VLCPlayerWrapper: subtitle delay set to \(seconds)s")
    }

    /// Loads an external subtitle file from a local file URL (e.g. downloaded from OpenSubtitles).
    func loadExternalSubtitle(fileURL: URL) {
        guard let player = mediaPlayer else { return }
        _ = player.addPlaybackSlave(fileURL, type: .subtitle, enforce: true)
        logger.info("VLCPlayerWrapper: loaded external subtitle from file \(fileURL.lastPathComponent, privacy: .public)")

        // Refresh tracks after a short delay to pick up the new subtitle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.refreshTracks()
        }
    }

    /// Loads an external subtitle from a remote URL (e.g. Jellyfin external subtitle stream).
    func loadExternalSubtitle(url: URL) {
        guard let player = mediaPlayer else { return }
        _ = player.addPlaybackSlave(url, type: .subtitle, enforce: false)
        logger.info("VLCPlayerWrapper: loaded external subtitle from URL \(url.absoluteString, privacy: .public)")

        // Refresh tracks after a short delay to pick up the new subtitle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.refreshTracks()
        }
    }

    /// Stops playback and resets state. The media player is retained for reuse.
    func stop() {
        guard let player = mediaPlayer else { return }
        if player.isPlaying || player.state != .stopped {
            player.stop()
        }
        resetState()
        logger.debug("VLCPlayerWrapper: stopped")
    }

    // MARK: - Private Helpers

    /// Resets all observable state to initial values.
    private func resetState() {
        isPlaying = false
        isPaused = false
        isBuffering = false
        hasError = false
        currentTimeMs = 0
        durationMs = 0
        progress = 0
        audioTracks = []
        subtitleTracks = []
        selectedAudioTrackIndex = -1
        selectedSubtitleTrackIndex = -1
        playbackRate = 1.0
        subtitleDelaySeconds = 0
    }

    /// Reads audio and subtitle tracks from the VLC player and updates the
    /// observable arrays. Called once playback begins so track info is available.
    private func refreshTracks() {
        guard let player = mediaPlayer else { return }

        // Audio tracks
        if let indexes = player.audioTrackIndexes as? [NSNumber],
           let names = player.audioTrackNames as? [String] {
            let paired = zip(indexes, names).map { (index: $0.intValue, title: $1) }
            DispatchQueue.main.async { [weak self] in
                self?.audioTracks = paired
                self?.selectedAudioTrackIndex = Int(player.currentAudioTrackIndex)
            }
        }

        // Subtitle tracks
        if let indexes = player.videoSubTitlesIndexes as? [NSNumber],
           let names = player.videoSubTitlesNames as? [String] {
            let paired = zip(indexes, names).map { (index: $0.intValue, title: $1) }
            DispatchQueue.main.async { [weak self] in
                self?.subtitleTracks = paired
                self?.selectedSubtitleTrackIndex = Int(player.currentVideoSubTitleIndex)
            }
        }
    }
}

// MARK: - VLCMediaPlayerDelegate

extension VLCPlayerWrapper: VLCMediaPlayerDelegate {

    /// Called by VLC on its internal thread whenever the player state changes.
    func mediaPlayerStateChanged(_ aNotification: Notification) {
        guard let player = mediaPlayer else { return }

        let state = player.state

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            self.isPlaying = (state == .playing)
            self.isPaused = (state == .paused)
            self.isBuffering = (state == .buffering)
            self.hasError = (state == .error)

            self.logger.debug("VLCPlayerWrapper: state changed to \(String(describing: state.rawValue))")
        }

        // When playback starts for the first time, read track information.
        if state == .playing {
            refreshTracks()
        }
    }

    /// Called by VLC on its internal thread whenever the playback time changes.
    func mediaPlayerTimeChanged(_ aNotification: Notification) {
        guard let player = mediaPlayer else { return }

        let timeMs = Int64(player.time.intValue)
        let lengthMs: Int64 = {
            guard let media = player.media else { return 0 }
            let val = media.length.intValue
            return val > 0 ? Int64(val) : 0
        }()

        let progressValue: Double = lengthMs > 0
            ? Double(timeMs) / Double(lengthMs)
            : 0

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.currentTimeMs = timeMs
            self.durationMs = lengthMs
            self.progress = min(max(progressValue, 0), 1)
        }
    }
}
