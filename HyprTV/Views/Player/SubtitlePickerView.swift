import SwiftUI

/// Sheet presenting a list of available subtitle tracks for the current media.
/// Includes an "Off" option to disable subtitles, distinguishes embedded from
/// external subs, and provides a "Download Subtitles" button for OpenSubtitles.
struct SubtitlePickerView: View {

    let viewModel: PlayerViewModel
    var itemName: String = ""
    var imdbId: String?
    var onExternalSubtitleLoaded: ((URL) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var showSubtitleSearch = false

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

                                    if track.isExternal == true {
                                        Image(systemName: "arrow.down.circle.fill")
                                            .font(.caption)
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
                    .buttonStyle(.plain)
                }

                // Download Subtitles section
                Section {
                    Button {
                        showSubtitleSearch = true
                    } label: {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.blue)
                            Text("Download Subtitles")
                                .font(.headline)
                                .foregroundStyle(.blue)
                            Spacer()
                            Image(systemName: "arrow.down.circle")
                                .foregroundStyle(.blue)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("OpenSubtitles")
                }
            }
            .navigationTitle("Subtitles")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showSubtitleSearch) {
                SubtitleSearchView(
                    itemName: itemName,
                    imdbId: imdbId,
                    onSubtitleDownloaded: { fileURL in
                        onExternalSubtitleLoaded?(fileURL)
                    }
                )
            }
        }
    }
}

// MARK: - Preview

#Preview {
    Text("Subtitle Picker Preview")
}
