import SwiftUI

/// View for searching and downloading subtitles from OpenSubtitles.
/// Presented as a sheet from the subtitle picker.
struct SubtitleSearchView: View {

    let itemName: String
    let imdbId: String?
    let onSubtitleDownloaded: (URL) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var results: [OpenSubtitlesService.SubtitleResult] = []
    @State private var isSearching = false
    @State private var downloadingFileId: Int?
    @State private var errorMessage: String?
    @State private var selectedLanguage: String = "en"

    private let service = OpenSubtitlesService()

    private static let languages: [(code: String, name: String)] = [
        ("en", "English"),
        ("es", "Spanish"),
        ("fr", "French"),
        ("de", "German"),
        ("it", "Italian"),
        ("pt", "Portuguese"),
        ("nl", "Dutch"),
        ("pl", "Polish"),
        ("ru", "Russian"),
        ("ja", "Japanese"),
        ("ko", "Korean"),
        ("zh", "Chinese"),
        ("ar", "Arabic"),
        ("sv", "Swedish"),
        ("da", "Danish"),
        ("fi", "Finnish"),
        ("no", "Norwegian"),
        ("tr", "Turkish"),
        ("cs", "Czech"),
        ("ro", "Romanian"),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Language selector
                languageSelector
                    .padding(.horizontal, 40)
                    .padding(.vertical, 16)

                if let errorMessage {
                    ContentUnavailableView {
                        Label("Error", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Retry") { searchSubtitles() }
                    }
                } else if isSearching {
                    Spacer()
                    ProgressView("Searching subtitles...")
                    Spacer()
                } else if results.isEmpty {
                    ContentUnavailableView {
                        Label("No Subtitles Found", systemImage: "captions.bubble")
                    } description: {
                        Text("Try a different language or search again.")
                    }
                } else {
                    resultsList
                }
            }
            .navigationTitle("Download Subtitles")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            searchSubtitles()
        }
    }

    // MARK: - Language Selector

    private var languageSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Self.languages, id: \.code) { lang in
                    Button {
                        selectedLanguage = lang.code
                        searchSubtitles()
                    } label: {
                        Text(lang.name)
                            .font(.callout)
                            .fontWeight(selectedLanguage == lang.code ? .semibold : .regular)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                selectedLanguage == lang.code
                                    ? Color.blue
                                    : Color.white.opacity(0.1),
                                in: Capsule()
                            )
                            .foregroundStyle(selectedLanguage == lang.code ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Results List

    private var resultsList: some View {
        List {
            ForEach(results) { result in
                Button {
                    downloadSubtitle(result)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(result.release)
                                .font(.headline)
                                .lineLimit(2)

                            HStack(spacing: 12) {
                                Label(result.languageName, systemImage: "globe")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Label("\(result.downloadCount)", systemImage: "arrow.down.circle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                if result.hearingImpaired {
                                    Text("CC")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.yellow)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                                }
                            }
                        }

                        Spacer()

                        if downloadingFileId == result.fileId {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.down.circle")
                                .font(.title3)
                                .foregroundStyle(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(downloadingFileId != nil)
            }
        }
    }

    // MARK: - Actions

    private func searchSubtitles() {
        isSearching = true
        errorMessage = nil
        results = []

        Task {
            do {
                if let imdbId, !imdbId.isEmpty {
                    results = try await service.searchByIMDB(
                        imdbId: imdbId,
                        language: selectedLanguage
                    )
                } else {
                    results = try await service.searchByQuery(
                        query: itemName,
                        language: selectedLanguage
                    )
                }
                // Sort by download count (most popular first)
                results.sort { $0.downloadCount > $1.downloadCount }
            } catch {
                errorMessage = error.localizedDescription
            }
            isSearching = false
        }
    }

    private func downloadSubtitle(_ result: OpenSubtitlesService.SubtitleResult) {
        downloadingFileId = result.fileId

        Task {
            do {
                let fileURL = try await service.download(fileId: result.fileId)
                onSubtitleDownloaded(fileURL)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                downloadingFileId = nil
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SubtitleSearchView(
        itemName: "Test Movie",
        imdbId: "tt1234567",
        onSubtitleDownloaded: { _ in }
    )
}
