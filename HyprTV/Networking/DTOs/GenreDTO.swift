import Foundation

/// Lightweight genre item returned by the /Genres endpoint.
struct GenreDTO: Codable, Identifiable, Hashable {
    let name: String
    let id: String

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case id = "Id"
    }
}
