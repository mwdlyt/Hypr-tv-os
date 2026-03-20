import Foundation
import os

// MARK: - OpenSubtitlesService

/// Client for the OpenSubtitles REST API v1 (api.opensubtitles.com).
/// Supports searching by IMDB ID or file name, downloading SRT files,
/// and parsing them into timed subtitle cues.
final class OpenSubtitlesService {

    // MARK: - Types

    struct SubtitleResult: Identifiable, Hashable {
        let id: String
        let fileId: Int
        let language: String
        let languageName: String
        let release: String
        let downloadCount: Int
        let hearingImpaired: Bool
        let rating: Double
    }

    struct SubtitleCue: Identifiable {
        let id: Int
        let startTime: TimeInterval
        let endTime: TimeInterval
        let text: String
    }

    enum OpenSubtitlesError: LocalizedError {
        case noAPIKey
        case searchFailed(statusCode: Int)
        case downloadFailed(statusCode: Int)
        case noDownloadLink
        case parseFailed
        case networkError(Error)

        var errorDescription: String? {
            switch self {
            case .noAPIKey:
                return "OpenSubtitles API key is not configured. Set it in Settings."
            case .searchFailed(let code):
                return "Subtitle search failed with HTTP \(code)."
            case .downloadFailed(let code):
                return "Subtitle download failed with HTTP \(code)."
            case .noDownloadLink:
                return "No download link returned for the selected subtitle."
            case .parseFailed:
                return "Failed to parse subtitle file."
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Properties

    private static let baseURL = "https://api.opensubtitles.com/api/v1"
    private let session: URLSession
    private let logger = Logger(subsystem: "com.hypr.tv", category: "OpenSubtitles")

    /// API key stored in UserDefaults. Configurable from Settings.
    static var apiKey: String {
        get { UserDefaults.standard.string(forKey: "opensubtitles_api_key") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "opensubtitles_api_key") }
    }

    // MARK: - Init

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - Search

    /// Searches for subtitles by IMDB ID.
    func searchByIMDB(imdbId: String, language: String? = nil) async throws -> [SubtitleResult] {
        var queryItems = [URLQueryItem(name: "imdb_id", value: imdbId)]
        if let language {
            queryItems.append(URLQueryItem(name: "languages", value: language))
        }
        return try await search(queryItems: queryItems)
    }

    /// Searches for subtitles by movie hash and file name.
    func searchByHash(movieHash: String, fileName: String, language: String? = nil) async throws -> [SubtitleResult] {
        var queryItems = [
            URLQueryItem(name: "moviehash", value: movieHash),
            URLQueryItem(name: "query", value: fileName)
        ]
        if let language {
            queryItems.append(URLQueryItem(name: "languages", value: language))
        }
        return try await search(queryItems: queryItems)
    }

    /// Searches for subtitles by query text (file name or title).
    func searchByQuery(query: String, language: String? = nil) async throws -> [SubtitleResult] {
        var queryItems = [URLQueryItem(name: "query", value: query)]
        if let language {
            queryItems.append(URLQueryItem(name: "languages", value: language))
        }
        return try await search(queryItems: queryItems)
    }

    private func search(queryItems: [URLQueryItem]) async throws -> [SubtitleResult] {
        let apiKey = Self.apiKey
        guard !apiKey.isEmpty else { throw OpenSubtitlesError.noAPIKey }

        var components = URLComponents(string: "\(Self.baseURL)/subtitles")!
        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.setValue(apiKey, forHTTPHeaderField: "Api-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("HyprTV v0.1.0", forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw OpenSubtitlesError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenSubtitlesError.networkError(URLError(.badServerResponse))
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw OpenSubtitlesError.searchFailed(statusCode: httpResponse.statusCode)
        }

        return try parseSearchResponse(data)
    }

    private func parseSearchResponse(_ data: Data) throws -> [SubtitleResult] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataArray = json["data"] as? [[String: Any]] else {
            return []
        }

        return dataArray.compactMap { item -> SubtitleResult? in
            guard let id = item["id"] as? String,
                  let attributes = item["attributes"] as? [String: Any],
                  let language = attributes["language"] as? String,
                  let files = attributes["files"] as? [[String: Any]],
                  let firstFile = files.first,
                  let fileId = firstFile["file_id"] as? Int else {
                return nil
            }

            return SubtitleResult(
                id: id,
                fileId: fileId,
                language: language,
                languageName: Locale.current.localizedString(forLanguageCode: language) ?? language,
                release: attributes["release"] as? String ?? "Unknown",
                downloadCount: attributes["download_count"] as? Int ?? 0,
                hearingImpaired: attributes["hearing_impaired"] as? Bool ?? false,
                rating: attributes["ratings"] as? Double ?? 0
            )
        }
    }

    // MARK: - Download

    /// Downloads a subtitle file and caches it locally. Returns the local file URL.
    func download(fileId: Int) async throws -> URL {
        let apiKey = Self.apiKey
        guard !apiKey.isEmpty else { throw OpenSubtitlesError.noAPIKey }

        // Step 1: Get download link
        let downloadURL = try await getDownloadLink(fileId: fileId, apiKey: apiKey)

        // Step 2: Download the actual file
        var request = URLRequest(url: downloadURL)
        request.setValue("HyprTV v0.1.0", forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw OpenSubtitlesError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw OpenSubtitlesError.downloadFailed(statusCode: code)
        }

        // Step 3: Save to cache directory
        let cacheDir = Self.subtitleCacheDirectory
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        let fileName = "subtitle_\(fileId).srt"
        let fileURL = cacheDir.appendingPathComponent(fileName)
        try data.write(to: fileURL)

        logger.info("OpenSubtitles: downloaded subtitle to \(fileURL.path, privacy: .public)")
        return fileURL
    }

    private func getDownloadLink(fileId: Int, apiKey: String) async throws -> URL {
        let url = URL(string: "\(Self.baseURL)/download")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "Api-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("HyprTV v0.1.0", forHTTPHeaderField: "User-Agent")

        let body = try JSONSerialization.data(withJSONObject: ["file_id": fileId])
        request.httpBody = body

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw OpenSubtitlesError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw OpenSubtitlesError.downloadFailed(statusCode: code)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let linkString = json["link"] as? String,
              let downloadURL = URL(string: linkString) else {
            throw OpenSubtitlesError.noDownloadLink
        }

        return downloadURL
    }

    // MARK: - SRT Parsing

    /// Parses an SRT file into an array of timed subtitle cues.
    static func parseSRT(fileURL: URL) throws -> [SubtitleCue] {
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        return parseSRTContent(content)
    }

    /// Parses SRT formatted text into subtitle cues.
    static func parseSRTContent(_ content: String) -> [SubtitleCue] {
        var cues: [SubtitleCue] = []
        let blocks = content.components(separatedBy: "\n\n")

        for block in blocks {
            let lines = block.trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: "\n")
            guard lines.count >= 3 else { continue }

            // Line 0: sequence number
            guard let index = Int(lines[0].trimmingCharacters(in: .whitespaces)) else { continue }

            // Line 1: timestamps  "00:01:23,456 --> 00:01:26,789"
            let timeParts = lines[1].components(separatedBy: " --> ")
            guard timeParts.count == 2,
                  let startTime = parseTimestamp(timeParts[0].trimmingCharacters(in: .whitespaces)),
                  let endTime = parseTimestamp(timeParts[1].trimmingCharacters(in: .whitespaces)) else {
                continue
            }

            // Lines 2+: subtitle text
            let text = lines[2...].joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !text.isEmpty else { continue }

            cues.append(SubtitleCue(
                id: index,
                startTime: startTime,
                endTime: endTime,
                text: text
            ))
        }

        return cues
    }

    /// Parses an SRT timestamp like "00:01:23,456" to seconds.
    private static func parseTimestamp(_ string: String) -> TimeInterval? {
        let parts = string.replacingOccurrences(of: ",", with: ".").components(separatedBy: ":")
        guard parts.count == 3,
              let hours = Double(parts[0]),
              let minutes = Double(parts[1]),
              let seconds = Double(parts[2]) else {
            return nil
        }
        return hours * 3600 + minutes * 60 + seconds
    }

    // MARK: - Cache

    /// Directory for cached subtitle files.
    static var subtitleCacheDirectory: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return caches.appendingPathComponent("Subtitles", isDirectory: true)
    }

    /// Removes all cached subtitle files.
    static func clearCache() throws {
        let dir = subtitleCacheDirectory
        if FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.removeItem(at: dir)
        }
    }
}
