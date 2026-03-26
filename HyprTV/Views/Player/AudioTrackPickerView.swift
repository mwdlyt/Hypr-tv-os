import SwiftUI

/// Sheet presenting available audio tracks from VLC.
/// Shows VLC track names and indicates the currently selected track.
struct AudioTrackPickerView: View {

    let vlcWrapper: VLCPlayerWrapper
    let viewModel: PlayerViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // VLC audio tracks
                ForEach(vlcWrapper.audioTracks, id: \.index) { track in
                    Button {
                        vlcWrapper.setAudioTrack(index: track.index)
                        // Also update viewModel's selected track if matching by index
                        if let jellyfinTrack = viewModel.audioTracks.first(where: { $0.index == track.index }) {
                            viewModel.selectAudioTrack(jellyfinTrack)
                        }
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(track.title)
                                    .font(.headline)

                                // Show Jellyfin metadata if available
                                if let jellyfinTrack = viewModel.audioTracks.first(where: { $0.index == track.index }) {
                                    HStack(spacing: 8) {
                                        if let language = jellyfinTrack.language {
                                            Text(language.uppercased())
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        if let codec = jellyfinTrack.codec {
                                            Text(codec.uppercased())
                                                .font(.caption)
                                                .foregroundStyle(.tertiary)
                                        }
                                        if let channels = jellyfinTrack.channels {
                                            Text(channelLayout(channels))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        if jellyfinTrack.isDefault == true {
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
                            }

                            Spacer()

                            if vlcWrapper.selectedAudioTrackIndex == track.index {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                                    .fontWeight(.semibold)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                if vlcWrapper.audioTracks.isEmpty {
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
