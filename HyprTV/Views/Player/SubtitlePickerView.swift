import SwiftUI

/// Sheet presenting available subtitle tracks from VLC.
/// Includes an "Off" option and subtitle appearance settings.
struct SubtitlePickerView: View {

    let vlcWrapper: VLCPlayerWrapper
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
                        vlcWrapper.setSubtitleTrack(index: -1)
                        viewModel.selectSubtitleTrack(nil)
                        dismiss()
                    } label: {
                        HStack {
                            Text("Off")
                                .font(.headline)
                            Spacer()
                            if vlcWrapper.selectedSubtitleTrackIndex == -1 {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                                    .fontWeight(.semibold)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                // Available subtitle tracks from VLC
                if !vlcWrapper.subtitleTracks.isEmpty {
                    Section {
                        ForEach(vlcWrapper.subtitleTracks, id: \.index) { track in
                            Button {
                                vlcWrapper.setSubtitleTrack(index: track.index)
                                // Update viewModel if matching Jellyfin track exists
                                if let jellyfinTrack = viewModel.subtitleTracks.first(where: { $0.index == track.index }) {
                                    viewModel.selectSubtitleTrack(jellyfinTrack)
                                }
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(track.title)
                                            .font(.headline)

                                        // Show Jellyfin metadata if available
                                        if let jellyfinTrack = viewModel.subtitleTracks.first(where: { $0.index == track.index }) {
                                            HStack(spacing: 8) {
                                                if let language = jellyfinTrack.language {
                                                    Text(language.uppercased())
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }
                                                if let codec = jellyfinTrack.codec {
                                                    Text(codec.uppercased())
                                                        .font(.caption)
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                                                }
                                                if jellyfinTrack.isForced == true {
                                                    Text("FORCED")
                                                        .font(.caption2)
                                                        .fontWeight(.semibold)
                                                        .foregroundStyle(.orange)
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                                                }
                                                if jellyfinTrack.isExternal == true {
                                                    Label("External", systemImage: "doc.text")
                                                        .font(.caption2)
                                                        .foregroundStyle(.cyan)
                                                }
                                            }
                                        }
                                    }

                                    Spacer()

                                    if vlcWrapper.selectedSubtitleTrackIndex == track.index {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                            .fontWeight(.semibold)
                                    }
                                }
                                .contentShape(Rectangle())
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
}
