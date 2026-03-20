import UIKit
import os

/// Multi-tier image loader: memory cache → disk cache → network.
///
/// Designed for large libraries where thousands of posters must load without
/// re-downloading. NSCache handles the hot set; a simple file-based disk cache
/// survives app restarts and memory pressure evictions.
actor ImageLoader {

    static let shared = ImageLoader()

    // MARK: - Memory Cache (Tier 1)

    private let memoryCache = NSCache<NSString, UIImage>()

    // MARK: - Disk Cache (Tier 2)

    private let diskCacheURL: URL
    private let fileManager = FileManager.default

    /// Maximum disk cache size in bytes (200 MB).
    private static let maxDiskCacheBytes: Int = 200 * 1024 * 1024

    // MARK: - In-flight deduplication

    private var inFlightRequests: [URL: Task<UIImage?, Never>] = [:]

    // MARK: - Logging

    private static let log = Logger(subsystem: "com.hypr.tv", category: "ImageLoader")

    // MARK: - Init

    private init() {
        // Memory cache: 150 items, 80 MB — generous enough that scrolling
        // through a full grid page never evicts visible posters.
        memoryCache.countLimit = 150
        memoryCache.totalCostLimit = 80 * 1024 * 1024

        // Disk cache lives in Caches so the OS can reclaim it under pressure.
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskCacheURL = caches.appendingPathComponent("HyprTV_ImageCache", isDirectory: true)

        if !fileManager.fileExists(atPath: diskCacheURL.path) {
            try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
        }
    }

    // MARK: - Public API

    /// Loads an image through the three-tier pipeline: memory → disk → network.
    /// Concurrent requests for the same URL are deduplicated.
    func loadImage(from url: URL) async -> UIImage? {
        let cacheKey = url.absoluteString as NSString

        // Tier 1: Memory cache (instant).
        if let cached = memoryCache.object(forKey: cacheKey) {
            return cached
        }

        // Tier 2: Disk cache (fast I/O, no network).
        if let diskImage = loadFromDisk(url: url) {
            storeInMemory(diskImage, key: cacheKey)
            return diskImage
        }

        // Deduplicate concurrent network requests for the same URL.
        if let existingTask = inFlightRequests[url] {
            return await existingTask.value
        }

        // Tier 3: Network download.
        let task = Task<UIImage?, Never> {
            await downloadImage(from: url)
        }
        inFlightRequests[url] = task

        let image = await task.value

        if let image {
            storeInMemory(image, key: cacheKey)
            storeToDisk(image, url: url)
        }

        inFlightRequests[url] = nil
        return image
    }

    /// Prefetches a batch of URLs into memory/disk cache in the background.
    /// Useful for loading the next page of results before the user scrolls there.
    func prefetch(urls: [URL]) {
        for url in urls {
            let cacheKey = url.absoluteString as NSString
            if memoryCache.object(forKey: cacheKey) != nil { continue }

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
    }

    /// Removes only the in-memory cache. Disk cache stays for next launch.
    func clearMemoryCache() {
        memoryCache.removeAllObjects()
    }

    // MARK: - Memory Cache Helpers

    private func storeInMemory(_ image: UIImage, key: NSString) {
        let cost = Int(image.size.width * image.size.height * image.scale * 4)
        memoryCache.setObject(image, forKey: key, cost: cost)
    }

    // MARK: - Disk Cache Helpers

    private func diskPath(for url: URL) -> URL {
        // SHA-like deterministic filename from the URL string.
        let filename = url.absoluteString.data(using: .utf8)!
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .prefix(128)
        return diskCacheURL.appendingPathComponent(String(filename))
    }

    private func loadFromDisk(url: URL) -> UIImage? {
        let path = diskPath(for: url)
        guard let data = try? Data(contentsOf: path) else { return nil }
        return UIImage(data: data)
    }

    private func storeToDisk(_ image: UIImage, url: URL) {
        let path = diskPath(for: url)
        // JPEG at 0.85 quality is a good trade-off between size and fidelity for posters.
        guard let data = image.jpegData(compressionQuality: 0.85) else { return }
        try? data.write(to: path, options: .atomic)
    }

    // MARK: - Network Download

    private func downloadImage(from url: URL) async -> UIImage? {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return nil
            }

            // Downscale on decode to reduce memory footprint for large artwork.
            return downsampledImage(data: data, maxPixelSize: 600)
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
