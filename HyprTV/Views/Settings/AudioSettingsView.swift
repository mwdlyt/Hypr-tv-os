import SwiftUI

struct AudioSettingsView: View {
    @Environment(AudioSettings.self) private var audioSettings

    var body: some View {
        @Bindable var settings = audioSettings

        List {
            // MARK: - Device Info
            Section {
                LabeledContent("Output Device") {
                    Text(audioSettings.detectedCapability.outputPortName)
                }
                LabeledContent("Detected Channels") {
                    Text(audioSettings.detectedCapability.channelLayoutName)
                }
                LabeledContent("Recommended Mode") {
                    Text(audioSettings.detectedCapability.recommendedMode.displayName)
                        .foregroundStyle(.secondary)
                }

                Button("Refresh Detection") {
                    audioSettings.detectDeviceCapabilities()
                }
            } header: {
                Text("Audio Device")
            } footer: {
                Text("Connect your soundbar or receiver, then tap Refresh to detect its capabilities.")
            }

            // MARK: - Output Mode
            Section {
                Picker("Audio Output Mode", selection: $settings.outputMode) {
                    ForEach(AudioOutputMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }

                if audioSettings.outputMode != .passthrough {
                    let effective = audioSettings.effectiveOutputMode
                    LabeledContent("Active Mode") {
                        Text(effective.displayName)
                            .foregroundStyle(.green)
                    }
                }
            } header: {
                Text("Downmixing")
            } footer: {
                Text(audioSettings.outputMode.description)
            }

            // MARK: - Audio Boost
            Section {
                Toggle("Volume Normalization", isOn: $settings.audioBoostEnabled)

                if audioSettings.audioBoostEnabled {
                    LabeledContent("Boost Level") {
                        Text("\(Int(audioSettings.audioBoostLevel)) dB")
                    }
                    Slider(value: $settings.audioBoostLevel, in: 0...20, step: 1) {
                        Text("Boost")
                    }
                }
            } header: {
                Text("Volume Boost")
            } footer: {
                Text("Normalizes quiet audio tracks so dialogue is easier to hear. Higher values increase overall volume.")
            }

            // MARK: - Preferred Languages
            Section {
                Picker("Audio Language", selection: $settings.preferredAudioLanguage) {
                    ForEach(AudioSettings.audioLanguages, id: \.code) { lang in
                        Text(lang.name).tag(lang.code)
                    }
                }

                Picker("Subtitle Language", selection: $settings.preferredSubtitleLanguage) {
                    ForEach(AudioSettings.subtitleLanguages, id: \.code) { lang in
                        Text(lang.name).tag(lang.code)
                    }
                }
            } header: {
                Text("Preferred Languages")
            } footer: {
                Text("Automatically selects matching audio and subtitle tracks when available.")
            }
        }
        .navigationTitle("Audio Settings")
    }
}
