import SwiftUI

/// Horizontal scrolling row of cast and crew members with profile photos.
struct CastCrewRow: View {

    let people: [PersonDTO]

    @Environment(JellyfinClient.self) private var jellyfinClient

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cast & Crew")
                .font(.title3)
                .fontWeight(.semibold)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 20) {
                    // Use index-based identity: Jellyfin can return the same
                    // person ID twice when someone is both an actor and a
                    // director on the same title, which would crash
                    // ForEach's uniqueness assertion.
                    ForEach(Array(people.enumerated()), id: \.offset) { _, person in
                        personCard(person)
                    }
                }
                .padding(.vertical, 8)
            }
            .focusSection()
        }
    }

    private func personCard(_ person: PersonDTO) -> some View {
        VStack(spacing: 8) {
            // Circular avatar via shared ImageLoader (3-tier cache) so
            // scrolling back to a detail view doesn't re-download portraits.
            if let imageURL = personImageURL(person) {
                AsyncPosterImage(url: imageURL, width: 100, height: 100)
                    .clipShape(Circle())
            } else {
                personPlaceholder
            }

            Text(person.name)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)

            if let subtitle = personSubtitle(person) {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: 120)
    }

    private var personPlaceholder: some View {
        Circle()
            .fill(.ultraThinMaterial)
            .frame(width: 100, height: 100)
            .overlay {
                Image(systemName: "person.fill")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
            }
    }

    private func personSubtitle(_ person: PersonDTO) -> String? {
        if let role = person.role, !role.isEmpty {
            return role
        }
        if let type = person.type, type != "Actor" {
            return type
        }
        return nil
    }

    private func personImageURL(_ person: PersonDTO) -> URL? {
        guard person.primaryImageTag != nil else { return nil }
        return jellyfinClient.imageURL(
            itemId: person.id,
            imageType: "Primary",
            maxWidth: 200,
            tag: person.primaryImageTag
        )
    }
}
