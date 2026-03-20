import SwiftUI

/// Sheet presenting a list of available subtitle tracks for the current media.
/// Includes an "Off" option to disable subtitles.
struct SubtitlePickerView: View {

    let viewModel: PlayerViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Off option
                Button {
                    viewModel.selectSubtitleTrack(nil)
                    dismiss()
                } label: {
                    HStack {
                        Text("Off")
                            .font(.headline)

                        Spacer()

                        if viewModel.selectedSubtitleTrack == nil {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                                .fontWeight(.semibold)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // Subtitle tracks
                ForEach(viewModel.subtitleTracks, id: \.index) { track in
                    Button {
                        viewModel.selectSubtitleTrack(track)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(track.displayTitle ?? "Subtitle Track \(track.index)")
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

                                    if track.isForced == true {
                                        Text("FORCED")
                                            .font(.caption2)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.orange)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                                    }
                                }
                            }

                            Spacer()

                            if viewModel.selectedSubtitleTrack?.index == track.index {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                                    .fontWeight(.semibold)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Subtitles")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    Text("Subtitle Picker Preview")
}
