import SwiftUI

/// Horizontal row of genre pill/capsule tags.
struct GenreTagsView: View {

    let genres: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Genres")
                .font(.headline)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(genres, id: \.self) { genre in
                        Text(genre)
                            .font(.callout)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                }
            }
            .focusSection()
        }
    }
}
