import Foundation
import AVFoundation
import os

// MARK: - AudioOutputMode

enum AudioOutputMode: Int, CaseIterable, Codable {
    case auto = 0
    case passthrough = 1
    case downmixTo5_1 = 2
    case downmixToStereo = 3

    var displayName: String {
        switch self {
        case .auto: return "Auto (Detect Device)"
        case .passthrough: return "Passthrough (Raw)"
        case .downmixTo5_1: return "Downmix to 5.1"
        case .downmixToStereo: return "Downmix to Stereo"
        }
    }

    var description: String {
        switch self {
        case .auto:
            return "Automatically detects your audio device and downmixes to the highest supported channel layout."
        case .passthrough:
            return "Sends the original audio bitstream to your receiver. Use when your receiver handles all decoding."
        case .downmixTo5_1:
            return "Converts 7.1 and higher audio to 5.1 surround. Ideal for 5.1 soundbars and older receivers."
        case .downmixToStereo:
            return "Converts all surround audio to stereo. Use with TV speakers or stereo headphones."
        }
    }

    /// The number of output channels for this mode, or nil for passthrough/auto.
    var channelCount: Int? {
        switch self {
        case .auto: return nil
        case .passthrough: return nil
        case .downmixTo5_1: return 6
        case .downmixToStereo: return 2
        }
    }
}

// MARK: - DeviceAudioCapability

struct DeviceAudioCapability {
    let maxChannels: Int
    let outputPortType: AVAudioSession.Port?
    let outputPortName: String

    var channelLayoutName: String {
        switch maxChannels {
        case 0: return "Unknown"
        case 1: return "Mono"
        case 2: return "Stereo"
        case 6: return "5.1 Surround"
        case 8: return "7.1 Surround"
        default: return "\(maxChannels) Channels"
        }
    }

    var supports7_1: Bool { maxChannels >= 8 }
    var supports5_1: Bool { maxChannels >= 6 }
    var supportsStereo: Bool { maxChannels >= 2 }

    /// Determines the best output mode given device capabilities.
    var recommendedMode: AudioOutputMode {
        if supports7_1 {
            return .passthrough
        } else if supports5_1 {
            return .downmixTo5_1
        } else {
            return .downmixToStereo
        }
    }
}

// MARK: - AudioSettings

@Observable
final class AudioSettings {

    private static let outputModeKey = "audio_output_mode"
    private static let preferredAudioLangKey = "preferred_audio_language"
    private static let preferredSubtitleLangKey = "preferred_subtitle_language"
    private static let audioBoostEnabledKey = "audio_boost_enabled"
    private static let audioBoostLevelKey = "audio_boost_level"

    private let defaults = UserDefaults.standard
    private let logger = Logger(subsystem: "com.hypr.tv", category: "AudioSettings")

    // MARK: - Properties

    var outputMode: AudioOutputMode {
        didSet { defaults.set(outputMode.rawValue, forKey: Self.outputModeKey) }
    }

    var preferredAudioLanguage: String {
        didSet { defaults.set(preferredAudioLanguage, forKey: Self.preferredAudioLangKey) }
    }

    var preferredSubtitleLanguage: String {
        didSet { defaults.set(preferredSubtitleLanguage, forKey: Self.preferredSubtitleLangKey) }
    }

    var audioBoostEnabled: Bool {
        didSet { defaults.set(audioBoostEnabled, forKey: Self.audioBoostEnabledKey) }
    }

    /// Volume normalization boost in dB (0–20).
    var audioBoostLevel: Double {
        didSet {
            let clamped = min(max(audioBoostLevel, 0), 20)
            if clamped != audioBoostLevel { audioBoostLevel = clamped }
            defaults.set(clamped, forKey: Self.audioBoostLevelKey)
        }
    }

    // MARK: - Device Detection

    var detectedCapability: DeviceAudioCapability = DeviceAudioCapability(
        maxChannels: 2, outputPortType: nil, outputPortName: "Unknown"
    )

    // MARK: - Init

    init() {
        let stored = defaults.integer(forKey: Self.outputModeKey)
        self.outputMode = AudioOutputMode(rawValue: stored) ?? .auto
        self.preferredAudioLanguage = defaults.string(forKey: Self.preferredAudioLangKey) ?? "eng"
        self.preferredSubtitleLanguage = defaults.string(forKey: Self.preferredSubtitleLangKey) ?? "eng"
        self.audioBoostEnabled = defaults.bool(forKey: Self.audioBoostEnabledKey)
        self.audioBoostLevel = defaults.double(forKey: Self.audioBoostLevelKey)
        if audioBoostLevel == 0 && !defaults.bool(forKey: Self.audioBoostEnabledKey) {
            audioBoostLevel = 6.0 // sensible default
        }

        detectDeviceCapabilities()
    }

    // MARK: - Device Capability Detection

    func detectDeviceCapabilities() {
        let session = AVAudioSession.sharedInstance()

        do {
            try session.setCategory(.playback, mode: .moviePlayback)
            try session.setActive(true)
        } catch {
            logger.error("AudioSettings: Failed to activate AVAudioSession: \(error.localizedDescription)")
        }

        let route = session.currentRoute
        var maxChannels = 2
        var portType: AVAudioSession.Port?
        var portName = "TV Speakers"

        for output in route.outputs {
            let channels = output.channels?.count ?? 2
            if channels > maxChannels {
                maxChannels = channels
            }
            portType = output.portType
            portName = output.portName
        }

        // AVAudioSession may report max hardware channels via maximumOutputNumberOfChannels
        let hardwareMax = session.maximumOutputNumberOfChannels
        if hardwareMax > maxChannels {
            maxChannels = hardwareMax
        }

        detectedCapability = DeviceAudioCapability(
            maxChannels: maxChannels,
            outputPortType: portType,
            outputPortName: portName
        )

        logger.info("AudioSettings: Detected \(maxChannels) output channels via \(portName)")
    }

    /// Returns the effective output mode, resolving `.auto` to the best match for the device.
    var effectiveOutputMode: AudioOutputMode {
        if outputMode == .auto {
            return detectedCapability.recommendedMode
        }
        return outputMode
    }

    /// Returns VLC media options dictionary for the current audio configuration.
    func vlcAudioOptions() -> [String: Any] {
        var options: [String: Any] = [:]
        let effective = effectiveOutputMode

        switch effective {
        case .passthrough:
            // Let VLC pass the raw bitstream through
            options["--spdif"] = ""
            options["--audio-replay-gain-mode"] = "none"

        case .downmixTo5_1:
            options["--audio-channels"] = 6
            options["--stereo-mode"] = 0   // non-stereo
            options["--force-dolby-surround"] = 1

        case .downmixToStereo:
            options["--audio-channels"] = 2
            options["--stereo-mode"] = 1   // stereo downmix
            options["--force-dolby-surround"] = 2  // Dolby Surround compatible stereo

        case .auto:
            // Should not reach here since effectiveOutputMode resolves it
            break
        }

        // Volume normalization / audio boost
        if audioBoostEnabled {
            options["--audio-replay-gain-mode"] = "track"
            options["--audio-replay-gain-default"] = audioBoostLevel
            options["--norm-max-level"] = audioBoostLevel
        }

        return options
    }

    // MARK: - Common Languages

    static let audioLanguages: [(code: String, name: String)] = [
        ("eng", "English"),
        ("jpn", "Japanese"),
        ("spa", "Spanish"),
        ("fre", "French"),
        ("ger", "German"),
        ("ita", "Italian"),
        ("por", "Portuguese"),
        ("rus", "Russian"),
        ("kor", "Korean"),
        ("chi", "Chinese"),
        ("hin", "Hindi"),
        ("ara", "Arabic"),
        ("tha", "Thai"),
        ("pol", "Polish"),
        ("dut", "Dutch"),
        ("swe", "Swedish"),
        ("nor", "Norwegian"),
        ("dan", "Danish"),
        ("fin", "Finnish"),
        ("tur", "Turkish"),
    ]

    static let subtitleLanguages: [(code: String, name: String)] = [
        ("off", "Off"),
    ] + audioLanguages
}
