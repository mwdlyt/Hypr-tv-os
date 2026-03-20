import SwiftUI

/// Sheet presenting available subtitle tracks from Jellyfin (embedded + external + plugin-provided).
/// Includes subtitle appearance customization.
struct SubtitlePickerView: View {

    let viewModel: PlayerViewModel
    var onStyleChanged: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var showStyleSettings = false

    var body: some View {
        NavigationStack {
            List {
                // Off option
                Section {
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
                }

                // Available subtitle tracks
                if !viewModel.subtitleTracks.isEmpty {
                    Section {
                        ForEach(viewModel.subtitleTracks, id: \.index) { track in
                            Button {
                                viewModel.selectSubtitleTrack(track)
                                dismiss()
                            } label: {
                                subtitleRow(for: track)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("Available Subtitles")
                    }
                }

                // Subtitle appearance settings
                Section {
                    Button {
                        showStyleSettings = true
                    } label: {
                        HStack {
                            Image(systemName: "textformat.size")
                                .foregroundStyle(.blue)
                            Text("Subtitle Appearance")
                                .font(.headline)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("Settings")
                }
            }
            .navigationTitle("Subtitles")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showStyleSettings) {
                SubtitleStyleView(onStyleChanged: onStyleChanged)
            }
        }
    }

    // MARK: - Subtitle Row

    private func subtitleRow(for track: MediaStreamDTO) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(track.displayTitle ?? "Track \(track.index)")
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
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
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

                    if track.isExternal == true {
                        Label("External", systemImage: "doc.text")
                            .font(.caption2)
                            .foregroundStyle(.cyan)
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
}
