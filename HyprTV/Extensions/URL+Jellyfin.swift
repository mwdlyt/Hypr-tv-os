import Foundation

extension URL {

    /// Appends a path component and optional query items to the URL.
    /// Returns nil only if the resulting URL cannot be constructed.
    func appendingPathComponent(_ component: String, queryItems: [URLQueryItem]) -> URL? {
        let base = self.appendingPathComponent(component)
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            return nil
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        return components.url
    }
}
