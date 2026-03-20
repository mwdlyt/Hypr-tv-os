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

            // Parental controls info (if restrictions are active)
            if let policy = jellyfinClient.userPolicy, policy.maxParentalRating != nil {
                Section {
                    LabeledContent("Content Restriction") {
                        if let maxRating = policy.maxParentalRating {
                            let ratingName = UserPolicy.ratingValues
                                .sorted { $0.value < $1.value }
                                .last(where: { $0.value <= maxRating })?.key ?? "Level \(maxRating)"
                            Text("Max: \(ratingName)")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let blockedTags = policy.blockedTags, !blockedTags.isEmpty {
                        LabeledContent("Blocked Tags") {
                            Text(blockedTags.joined(separator: ", "))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                } header: {
                    Text("Parental Controls")
                } footer: {
                    Text("Content restrictions are managed by your server administrator.")
                }
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
                Button("Switch Server") {
                    jellyfinClient.clearSession()
                }

                Button("Sign Out", role: .destructive) {
                    jellyfinClient.clearSession()
                    KeychainService.deleteAll()
                }
            } header: {
                Text("Account")
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
    var body: some View {
        SubtitleStyleView(onStyleChanged: nil)
    }
}
