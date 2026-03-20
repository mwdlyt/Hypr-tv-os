import Foundation

extension Data {

    /// Decodes this data as JSON into the specified Decodable type.
    /// The type can usually be inferred from context.
    func decoded<T: Decodable>(as type: T.Type = T.self) throws -> T {
        try JSONDecoder.jellyfin.decode(type, from: self)
    }
}

extension JSONDecoder {

    /// A shared decoder pre-configured for Jellyfin API responses.
    static let jellyfin: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()
}
