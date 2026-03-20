import SwiftUI

/// Sheet presenting a list of available audio tracks for the current media.
/// Shows language, codec, and channel information for each track.
struct AudioTrackPickerView: View {

    let viewModel: PlayerViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.audioTracks, id: \.index) { track in
                    Button {
                        viewModel.selectAudioTrack(track)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(track.displayTitle ?? "Audio Track \(track.index)")
                                    .font(.headline)

                                HStack(spacing: 8) {
                                    if let language = track.language {
                                        Text(language.uppercased())
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    if let codec = track.codec {
                                        Text(codec.uppercased())
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }

                                    if let channels = track.channels {
                                        Text(channelLayout(channels))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    if track.isDefault == true {
                                        Text("DEFAULT")
                                            .font(.caption2)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.blue)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(.blue.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                                    }
                                }
                            }

                            Spacer()

                            if viewModel.selectedAudioTrack?.index == track.index {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                                    .fontWeight(.semibold)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                if viewModel.audioTracks.isEmpty {
                    Text("No audio tracks available")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                }
            }
            .navigationTitle("Audio")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Helpers

    /// Converts channel count to a human-readable layout string.
    private func channelLayout(_ channels: Int) -> String {
        switch channels {
        case 1: return "Mono"
        case 2: return "Stereo"
        case 6: return "5.1"
        case 8: return "7.1"
        default: return "\(channels)ch"
        }
    }
}

// MARK: - Preview

#Preview {
    Text("Audio Track Picker Preview")
}
