import SwiftUI

/// Horizontal scrolling row of portrait poster cards with section title.
/// Reports focused item changes to the parent via `onItemFocused`.
struct MediaRowView: View {

    let title: String
    let items: [MediaItemDTO]
    var libraryId: String?
    /// Called when a poster in this row gains focus.
    var onItemFocused: ((MediaItemDTO?) -> Void)?

    @Environment(AppRouter.self) private var router

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Section header
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

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
                                .font(.caption2)
                        }
                        .foregroundStyle(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Constants.Layout.horizontalPadding)

            // Horizontal poster scroll
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Constants.Layout.posterSpacing) {
                    ForEach(items) { item in
                        MediaCardView(item: item, onFocused: {
                            onItemFocused?(item)
                        })
                    }
                }
                .padding(.horizontal, Constants.Layout.horizontalPadding)
                .padding(.vertical, 20)
            }
            .focusSection()
        }
    }
}
