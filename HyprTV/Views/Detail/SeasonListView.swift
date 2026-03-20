import SwiftUI

/// Horizontal scroll of season buttons for a TV series.
/// The currently selected season is visually highlighted.
struct SeasonListView: View {

    let seasons: [MediaItemDTO]
    let selectedSeason: MediaItemDTO?
    let onSelectSeason: (MediaItemDTO) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Seasons")
                .font(.title3)
                .fontWeight(.semibold)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(seasons) { season in
                        seasonButton(season: season)
                    }
                }
                .padding(.vertical, 8)
            }
            .focusSection()
        }
    }

    // MARK: - Season Button

    private func seasonButton(season: MediaItemDTO) -> some View {
        let isSelected = selectedSeason?.id == season.id

        return Button {
            onSelectSeason(season)
        } label: {
            VStack(spacing: 6) {
                Text(seasonLabel(for: season))
                    .font(.headline)
                    .fontWeight(isSelected ? .bold : .regular)

                if let count = season.userData?.unplayedItemCount, count > 0 {
                    Text("\(count) unwatched")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                isSelected
                    ? AnyShapeStyle(.blue.opacity(0.3))
                    : AnyShapeStyle(.ultraThinMaterial),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? .blue : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.card)
    }

    // MARK: - Helpers

    private func seasonLabel(for season: MediaItemDTO) -> String {
        if let index = season.indexNumber {
            return "Season \(index)"
        }
        return season.name
    }
}

// MARK: - Preview

#Preview {
    SeasonListView(
        seasons: [],
        selectedSeason: nil
    ) { _ in }
}
