import SwiftUI

struct SettingsView: View {
    @Environment(AudioSettings.self) private var audioSettings
    @Environment(JellyfinClient.self) private var jellyfinClient

    var body: some View {
        List {
            Section {
                NavigationLink("Audio & Downmixing") {
                    AudioSettingsView()
                }

                NavigationLink("Playback") {
                    PlaybackSettingsView()
                }

                NavigationLink("Subtitles") {
                    SubtitleSettingsView()
                }
            } header: {
                Text("Media")
            }

            Section {
                if let serverURL = jellyfinClient.baseURL {
                    LabeledContent("Server") {
                        Text(serverURL.host ?? serverURL.absoluteString)
                            .foregroundStyle(.secondary)
                    }
                }

                LabeledContent("Version") {
                    Text(Constants.clientVersion)
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Device ID") {
                    Text(String(Constants.deviceId.prefix(8)) + "...")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("About")
            }

            Section {
                Button("Sign Out", role: .destructive) {
                    jellyfinClient.clearSession()
                }
            }
        }
        .navigationTitle("Settings")
    }
}

// MARK: - Playback Settings

struct PlaybackSettingsView: View {
    var body: some View {
        List {
            Section {
                LabeledContent("Video Decoder") {
                    Text("Hardware Accelerated")
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Network Cache") {
                    Text("1500 ms")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Decoding")
            } footer: {
                Text("Hardware decoding is always preferred for best performance on Apple TV.")
            }

            Section {
                ForEach(codecGroups, id: \.title) { group in
                    LabeledContent(group.title) {
                        Text(group.codecs)
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            } header: {
                Text("Supported Formats")
            }
        }
        .navigationTitle("Playback")
    }

    private var codecGroups: [(title: String, codecs: String)] {
        [
            ("Video", "H.264, HEVC, VP9, AV1, MPEG-2, VC-1"),
            ("Audio", "DTS, DTS-HD MA, DTS-X, Dolby Digital, DD+, TrueHD, AAC, FLAC, PCM, MP3, Opus, Vorbis"),
            ("Subtitles", "SRT, ASS/SSA, PGS, DVDSUB, VobSub"),
            ("Containers", "MKV, MP4, AVI, MOV, WMV, FLV, TS, M2TS, ISO/BDMV"),
        ]
    }
}

// MARK: - Subtitle Settings

struct SubtitleSettingsView: View {
    @State private var apiKey: String = OpenSubtitlesService.apiKey

    var body: some View {
        List {
            Section {
                LabeledContent("OpenSubtitles API Key") {
                    TextField("Enter API Key", text: $apiKey)
                        .multilineTextAlignment(.trailing)
                        .autocorrectionDisabled()
                        .onChange(of: apiKey) { _, newValue in
                            OpenSubtitlesService.apiKey = newValue
                        }
                }
            } header: {
                Text("OpenSubtitles")
            } footer: {
                Text("An API key from api.opensubtitles.com is required to search and download subtitles. Register at opensubtitles.com to get one.")
            }

            Section {
                Button("Clear Subtitle Cache") {
                    try? OpenSubtitlesService.clearCache()
                }
            } header: {
                Text("Cache")
            } footer: {
                Text("Removes all downloaded subtitle files from the local cache.")
            }
        }
        .navigationTitle("Subtitles")
    }
}
