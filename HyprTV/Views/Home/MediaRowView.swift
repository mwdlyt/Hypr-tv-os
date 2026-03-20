import SwiftUI

/// Horizontal scrolling row of media cards with a section title and optional "See All" navigation.
struct MediaRowView: View {

    let title: String
    let items: [MediaItemDTO]
    var libraryId: String?

    @Environment(AppRouter.self) private var router

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // MARK: Section Header
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)

                Spacer()

                if let libraryId {
                    Button {
                        router.navigate(to: .library(LibraryDTO(
                            id: libraryId,
                            name: title.replacingOccurrences(of: "Latest in ", with: ""),
                            collectionType: nil,
                            imageTagsPrimary: nil
                        )))
                    } label: {
                        HStack(spacing: 4) {
                            Text("See All")
                                .font(.callout)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 60)

            // MARK: Horizontal Scroll
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 28) {
                    ForEach(items) { item in
                        MediaCardView(item: item)
                    }
                }
                .padding(.horizontal, 60)
                .padding(.vertical, 20)
            }
            .focusSection()
        }
    }
}

// MARK: - Preview

#Preview {
    MediaRowView(title: "Continue Watching", items: [], libraryId: nil)
}
