import UIKit
import CryptoKit
import os

/// Multi-tier image loader: memory cache → disk cache → network.
///
/// Designed for large libraries where thousands of posters must load without
/// re-downloading. NSCache handles the hot set; a simple file-based disk cache
/// survives app restarts and memory pressure evictions.
///
/// Security note: the cache key strips the `api_key` query parameter so the
/// Jellyfin access token is never persisted in cache filenames or in-memory
/// keys. Filenames are SHA-256 hashes of the canonicalised URL to avoid
/// filesystem-unsafe characters and cap length.
actor ImageLoader {

    static let shared = ImageLoader()

    // MARK: - Memory Cache (Tier 1)

    private let memoryCache = NSCache<NSString, UIImage>()

    // MARK: - Disk Cache (Tier 2)

    private let diskCacheURL: URL
    private let fileManager = FileManager.default

    /// Maximum disk cache size in bytes (200 MB). Enforced lazily after writes.
    private static let maxDiskCacheBytes: Int = 200 * 1024 * 1024
    /// Reduce the cache to this size when eviction runs so we don't thrash.
    private static let diskCacheEvictionTarget: Int = 150 * 1024 * 1024

    // MARK: - In-flight deduplication

    private var inFlightRequests: [String: Task<UIImage?, Never>] = [:]

    /// Tracks approximate disk cache size so we only stat the directory
    /// when eviction may be needed. -1 means "unknown, recompute".
    private var trackedDiskBytes: Int = -1
    /// Counts writes since the last eviction pass; we only audit every N writes.
    private var writesSinceAudit: Int = 0
    private static let auditInterval: Int = 20

    // MARK: - Logging

    private static let log = Logger(subsystem: "com.hypr.tv", category: "ImageLoader")

    // MARK: - Init

    private init() {
        // Memory cache: 150 items, 80 MB — generous enough that scrolling
        // through a full grid page never evicts visible posters.
        memoryCache.countLimit = 150
        memoryCache.totalCostLimit = 80 * 1024 * 1024

        // Disk cache lives in Caches so the OS can reclaim it under pressure.
        // Fall back to the temporary directory if the caches URL is unavailable
        // (prevents a force-unwrap crash on exotic platforms).
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        diskCacheURL = caches.appendingPathComponent("HyprTV_ImageCache", isDirectory: true)

        if !fileManager.fileExists(atPath: diskCacheURL.path) {
            try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
        }
    }

    // MARK: - Public API

    /// Loads an image through the three-tier pipeline: memory → disk → network.
    /// Concurrent requests for the same URL are deduplicated.
    ///
    /// - Parameters:
    ///   - url: The image URL to load.
    ///   - maxPixelSize: Longest-edge cap for decoded images. Pass a larger
    ///     value (e.g. 1920) for fullscreen backdrops, the default for posters.
    func loadImage(from url: URL, maxPixelSize: CGFloat = 600) async -> UIImage? {
        let key = cacheKey(for: url)
        let nsKey = key as NSString

        // Tier 1: Memory cache (instant).
        if let cached = memoryCache.object(forKey: nsKey) {
            return cached
        }

        // Tier 2: Disk cache (fast I/O, no network).
        if let diskImage = loadFromDisk(key: key) {
            storeInMemory(diskImage, key: nsKey)
            return diskImage
        }

        // Deduplicate concurrent network requests for the same canonical URL.
        if let existingTask = inFlightRequests[key] {
            return await existingTask.value
        }

        // Tier 3: Network download.
        let task = Task<UIImage?, Never> { [maxPixelSize] in
            await downloadImage(from: url, maxPixelSize: maxPixelSize)
        }
        inFlightRequests[key] = task

        let image = await task.value

        if let image {
            storeInMemory(image, key: nsKey)
            storeToDisk(image, key: key)
        }

        inFlightRequests[key] = nil
        return image
    }

    /// Prefetches a batch of URLs into memory/disk cache in the background.
    /// Useful for loading the next page of results before the user scrolls there.
    func prefetch(urls: [URL]) {
        for url in urls {
            let key = cacheKey(for: url) as NSString
            if memoryCache.object(forKey: key) != nil { continue }

            Task {
                _ = await loadImage(from: url)
            }
        }
    }

    /// Removes all cached images from memory and disk.
    func clearCache() {
        memoryCache.removeAllObjects()
        try? fileManager.removeItem(at: diskCacheURL)
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
        trackedDiskBytes = 0
        writesSinceAudit = 0
    }

    /// Removes only the in-memory cache. Disk cache stays for next launch.
    func clearMemoryCache() {
        memoryCache.removeAllObjects()
    }

    // MARK: - Cache Key

    /// Builds a stable cache key from a URL, stripping sensitive/volatile query
    /// parameters so the same image has the same key regardless of token rotation.
    private func cacheKey(for url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.absoluteString
        }
        // Strip credentials — never persist the access token in cache keys.
        components.queryItems = components.queryItems?.filter { item in
            item.name != "api_key" && item.name != "X-Emby-Token" && item.name != "ApiKey"
        }
        if components.queryItems?.isEmpty == true {
            components.queryItems = nil
        }
        return components.url?.absoluteString ?? url.absoluteString
    }

    // MARK: - Memory Cache Helpers

    private func storeInMemory(_ image: UIImage, key: NSString) {
        let cost = Int(image.size.width * image.size.height * image.scale * 4)
        memoryCache.setObject(image, forKey: key, cost: cost)
    }

    // MARK: - Disk Cache Helpers

    /// Deterministic, short, filesystem-safe filename derived from the
    /// canonicalised URL. Uses SHA-256 so tokens or long query strings don't
    /// leak into the filesystem.
    private func diskPath(for key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8))
        let filename = digest.map { String(format: "%02x", $0) }.joined()
        return diskCacheURL.appendingPathComponent(filename)
    }

    private func loadFromDisk(key: String) -> UIImage? {
        let path = diskPath(for: key)
        guard let data = try? Data(contentsOf: path) else { return nil }
        // Touch the modification date so LRU eviction keeps hot files alive.
        try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: path.path)
        return UIImage(data: data)
    }

    private func storeToDisk(_ image: UIImage, key: String) {
        let path = diskPath(for: key)
        // JPEG at 0.85 quality is a good trade-off between size and fidelity for posters.
        guard let data = image.jpegData(compressionQuality: 0.85) else { return }
        do {
            try data.write(to: path, options: .atomic)
            if trackedDiskBytes >= 0 {
                trackedDiskBytes += data.count
            }
            writesSinceAudit += 1
            if writesSinceAudit >= Self.auditInterval {
                writesSinceAudit = 0
                enforceCacheLimit()
            }
        } catch {
            Self.log.error("Image disk write failed: \(error.localizedDescription)")
        }
    }

    /// Scans the cache directory and evicts the least recently used files
    /// until total size drops below `diskCacheEvictionTarget`.
    private func enforceCacheLimit() {
        let resourceKeys: Set<URLResourceKey> = [.fileSizeKey, .contentModificationDateKey]
        guard let enumerator = fileManager.enumerator(
            at: diskCacheURL,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else {
            return
        }

        struct Entry {
            let url: URL
            let size: Int
            let modified: Date
        }

        var entries: [Entry] = []
        var totalBytes = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: resourceKeys),
                  let size = values.fileSize,
                  let modified = values.contentModificationDate else { continue }
            entries.append(Entry(url: fileURL, size: size, modified: modified))
            totalBytes += size
        }
        trackedDiskBytes = totalBytes

        guard totalBytes > Self.maxDiskCacheBytes else { return }

        Self.log.info("ImageLoader: evicting disk cache (\(totalBytes) bytes > \(Self.maxDiskCacheBytes))")

        // Sort oldest first; remove until under target.
        entries.sort { $0.modified < $1.modified }
        var remaining = totalBytes
        for entry in entries where remaining > Self.diskCacheEvictionTarget {
            do {
                try fileManager.removeItem(at: entry.url)
                remaining -= entry.size
            } catch {
                // Ignore individual failures — best effort eviction.
            }
        }
        trackedDiskBytes = remaining
    }

    // MARK: - Network Download

    private func downloadImage(from url: URL, maxPixelSize: CGFloat) async -> UIImage? {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return nil
            }

            // Downscale on decode to reduce memory footprint for large artwork.
            return downsampledImage(data: data, maxPixelSize: maxPixelSize)
        } catch {
            Self.log.error("Image download failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Creates a downsampled UIImage from data, capping the longest edge.
    /// This avoids holding full-resolution 4K artwork bitmaps in memory.
    private func downsampledImage(data: Data, maxPixelSize: CGFloat) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else {
            return UIImage(data: data)
        }

        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) else {
            return UIImage(data: data)
        }

        return UIImage(cgImage: cgImage)
    }
}
