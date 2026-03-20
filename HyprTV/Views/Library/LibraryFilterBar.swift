import SwiftUI

/// Filter bar for library grid — genre multi-select and content rating filter.
struct LibraryFilterBar: View {

    @Binding var selectedGenreIds: Set<String>
    @Binding var selectedRatings: Set<String>
    let availableGenres: [GenreDTO]

    private let commonRatings = ["G", "PG", "PG-13", "R", "NC-17", "NR",
                                  "TV-Y", "TV-Y7", "TV-G", "TV-PG", "TV-14", "TV-MA"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Genre filter
            if !availableGenres.isEmpty {
                genreSection
            }

            // Rating filter
            ratingSection
        }
    }

    // MARK: - Genre Section

    private var genreSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Genres")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                if !selectedGenreIds.isEmpty {
                    Button("Clear") {
                        selectedGenreIds.removeAll()
                    }
                    .font(.caption)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(availableGenres) { genre in
                        Button {
                            if selectedGenreIds.contains(genre.id) {
                                selectedGenreIds.remove(genre.id)
                            } else {
                                selectedGenreIds.insert(genre.id)
                            }
                        } label: {
                            Text(genre.name)
                                .font(.callout)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    selectedGenreIds.contains(genre.id)
                                        ? AnyShapeStyle(.blue)
                                        : AnyShapeStyle(.ultraThinMaterial),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .focusSection()
        }
    }

    // MARK: - Rating Section

    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Rating")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                if !selectedRatings.isEmpty {
                    Button("Clear") {
                        selectedRatings.removeAll()
                    }
                    .font(.caption)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(commonRatings, id: \.self) { rating in
                        Button {
                            if selectedRatings.contains(rating) {
                                selectedRatings.remove(rating)
                            } else {
                                selectedRatings.insert(rating)
                            }
                        } label: {
                            Text(rating)
                                .font(.callout)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    selectedRatings.contains(rating)
                                        ? AnyShapeStyle(.blue)
                                        : AnyShapeStyle(.ultraThinMaterial),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .focusSection()
        }
    }
}
