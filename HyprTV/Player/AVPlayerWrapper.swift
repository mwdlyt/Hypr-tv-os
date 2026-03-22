import Foundation
import AVFoundation
import AVKit
import UIKit
import os
import Observation

/// AVPlayer-based playback engine for Apple TV.
/// Handles direct play of formats Apple TV supports natively:
/// H.264, HEVC, AAC, AC3, E-AC3/Atmos, ALAC, MP3.
/// Falls back gracefully for unsupported formats.
@Observable
final class AVPlayerWrapper: NSObject {

    // MARK: - Observable State

    var isPlaying = false
    var isPaused = false
    var isBuffering = false
    var hasError = false
    var currentTimeMs: Int64 = 0
    var durationMs: Int64 = 0
    var progress: Double = 0
    var errorMessage: String?

    // MARK: - Player

    let player = AVPlayer()
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var statusObserver: NSKeyValueObservation?
    private var rateObserver: NSKeyValueObservation?
    private var bufferObserver: NSKeyValueObservation?
    private let logger = Logger(subsystem: "com.hypr.tv", category: "AVPlayer")

    // MARK: - Playback

    /// Metadata to display in the native transport bar.
    var mediaTitle: String = ""
    var mediaSubtitle: String = ""

    func playURL(_ url: URL, startPositionTicks: Int64 = 0) {
        // Stop any existing playback first
        stop()

        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        self.playerItem = item

        // Set metadata for native transport bar
        setNowPlayingMetadata(on: item)

        // Observe status
        statusObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                switch item.status {
                case .readyToPlay:
                    self.isBuffering = false
                    self.durationMs = Int64(CMTimeGetSeconds(item.duration) * 1000)

                    // Seek to resume position if needed
                    if startPositionTicks > 0 {
                        let seconds = Double(startPositionTicks) / 10_000_000.0
                        let time = CMTime(seconds: seconds, preferredTimescale: 1000)
                        self.player.seek(to: time) { _ in
                            self.player.play()
                        }
                    } else {
                        self.player.play()
                    }
                    self.logger.info("AVPlayerWrapper: ready to play")

                case .failed:
                    self.hasError = true
                    self.errorMessage = item.error?.localizedDescription ?? "Playback failed"
                    self.logger.error("AVPlayerWrapper: failed - \(item.error?.localizedDescription ?? "unknown")")

                default:
                    break
                }
            }
        }

        // Observe rate changes (play/pause)
        rateObserver = player.observe(\.rate, options: [.new]) { [weak self] player, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isPlaying = player.rate > 0
                self.isPaused = player.rate == 0 && self.currentTimeMs > 0
            }
        }

        // Observe buffering
        bufferObserver = item.observe(\.isPlaybackBufferEmpty, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                self?.isBuffering = item.isPlaybackBufferEmpty
            }
        }

        // Periodic time observer (every 0.5s)
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            let ms = Int64(CMTimeGetSeconds(time) * 1000)
            self.currentTimeMs = ms
            if self.durationMs > 0 {
                self.progress = Double(ms) / Double(self.durationMs)
            }
        }

        isBuffering = true
        player.replaceCurrentItem(with: item)
        logger.info("AVPlayerWrapper: loading \(url.absoluteString, privacy: .public)")
    }

    // MARK: - Controls

    func play() {
        player.play()
    }

    func pause() {
        player.pause()
    }

    func togglePlayPause() {
        if player.rate > 0 {
            pause()
        } else {
            play()
        }
    }

    func seek(to positionMs: Int64) {
        let seconds = Double(positionMs) / 1000.0
        let time = CMTime(seconds: seconds, preferredTimescale: 1000)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func seekRelative(by offsetMs: Int64) {
        let target = currentTimeMs + offsetMs
        let clamped = max(0, min(target, durationMs))
        seek(to: clamped)
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)

        if let timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        statusObserver?.invalidate()
        rateObserver?.invalidate()
        bufferObserver?.invalidate()
        statusObserver = nil
        rateObserver = nil
        bufferObserver = nil

        isPlaying = false
        isPaused = false
        isBuffering = false
        hasError = false
        currentTimeMs = 0
        durationMs = 0
        progress = 0
    }

    // MARK: - Metadata

    private func setNowPlayingMetadata(on item: AVPlayerItem) {
        var metadata: [AVMetadataItem] = []

        if !mediaTitle.isEmpty {
            let titleItem = AVMutableMetadataItem()
            titleItem.identifier = .commonIdentifierTitle
            titleItem.value = mediaTitle as NSString
            metadata.append(titleItem)
        }

        if !mediaSubtitle.isEmpty {
            let descItem = AVMutableMetadataItem()
            descItem.identifier = .commonIdentifierDescription
            descItem.value = mediaSubtitle as NSString
            metadata.append(descItem)
        }

        item.externalMetadata = metadata
    }

    // MARK: - Audio/Subtitle Selection

    func selectAudioTrack(index: Int) {
        guard let item = playerItem,
              let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .audible) else { return }
        let options = group.options
        if index >= 0 && index < options.count {
            item.select(options[index], in: group)
        }
    }

    func selectSubtitleTrack(index: Int) {
        guard let item = playerItem,
              let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else { return }
        if index < 0 {
            item.select(nil, in: group) // disable subtitles
        } else {
            let options = group.options
            if index < options.count {
                item.select(options[index], in: group)
            }
        }
    }
}
