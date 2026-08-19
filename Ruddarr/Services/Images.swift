import Foundation
import CryptoKit
import Nuke

class Images {
    static let cacheName: String = "com.ruddarr.images"

    static let shared: ImagePipeline = {
        var config = ImagePipeline.Configuration.withDataCache(name: cacheName)
        config.dataCachePolicy = .automatic
        config.imageCache = ImageCache.shared

        return ImagePipeline(configuration: config)
    }()

    private static var dataCache: DataCache? {
        shared.configuration.dataCache as? DataCache
    }

    @concurrent
    static func clearCache() async {
        shared.cache.removeAll()
        dataCache?.flush()

        URLCache.shared.removeAllCachedResponses()

        try? FileManager.default.removeItem(at: localCopies)
    }

    @concurrent
    static func cacheSize() async -> Int {
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey]

        let copies = FileManager.default.enumerator(
            at: localCopies, includingPropertiesForKeys: Array(keys)
        )?.compactMap { $0 as? URL } ?? []

        return copies.reduce(dataCache?.totalSize ?? 0) { total, file in
            total + ((try? file.resourceValues(forKeys: keys).totalFileAllocatedSize) ?? 0)
        }
    }

    static func request(
        _ url: URL,
        _ type: ImageType,
        _ priority: ImageRequest.Priority = .normal
    ) -> ImageRequest {
        ImageRequest(
            urlRequest: URLRequest(url: sized(url), timeoutInterval: 5),
            processors: [
                .resize(
                    size: type.size,
                    contentMode: type.contentMode,
                    crop: type.crop,
                    upscale: true
                )
            ],
            priority: priority
        )
    }

    private static func sized(_ url: URL) -> URL {
        guard let host = url.host else { return url }

        // use w780 as source for TMDb posters
        if host.hasSuffix("image.tmdb.org") {
            let sized = url.absoluteString.replacingOccurrences(of: "/t/p/original/", with: "/t/p/w780/")
            return URL(string: sized) ?? url
        }

        return url
    }

    static func thumbnail(_ poster: String?, _ priority: ImageRequest.Priority = .normal) async -> URL? {
        guard let poster else { return nil }
        guard let url = URL(string: poster) else { return nil }

        let pipeline = Self.shared
        let request = self.request(url, .poster, priority)

        let cacheKey = pipeline.cache.makeDataCacheKey(for: request)
        let thumbnail = thumbnailPath(cacheKey)

        if pipeline.cache.containsData(for: request) {
            return thumbnail
        }

        do {
            _ = try await pipeline.imageTask(with: request).response
        } catch {
            //
        }

        return thumbnail
    }

    private static func thumbnailPath(_ key: String) -> URL? {
        FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("com.ruddarr.images/\(sha1(of: key))")
    }

    private static let localCopies: URL = FileManager.default
        .temporaryDirectory
        .appendingPathComponent("com.ruddarr.quicklook")

    static func localCopy(of remote: String?, named filename: String? = nil) async -> URL? {
        guard let remote, let url = URL(string: remote) else { return nil }

        if let cached = hasLocalCopy(of: remote, named: filename) {
            return cached
        }

        let file = localCopyPath(for: url, named: filename)

        do {
            let (data, _) = try await URLSession.shared.data(from: url)

            try FileManager.default.createDirectory(
                at: file.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            try data.write(to: file)

            return file
        } catch {
            return nil
        }
    }

    static func hasLocalCopy(of remote: String?, named filename: String? = nil) -> URL? {
        guard let remote, let url = URL(string: remote) else { return nil }

        let file = localCopyPath(for: url, named: filename)

        return FileManager.default.fileExists(atPath: file.path) ? file : nil
    }

    private static func localCopyPath(for url: URL, named filename: String?) -> URL {
        let pathExtension = url.pathExtension.isEmpty ? "jpg" : url.pathExtension

        let illegal = CharacterSet(charactersIn: "/\\:*?\"<>|").union(.newlines)

        let name = filename
            .map {
                $0.components(separatedBy: illegal)
                    .joined(separator: " ")
                    .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
            }
            .flatMap {
                $0.isEmpty ? nil : $0
            } ?? url.deletingPathExtension().lastPathComponent

        return localCopies
            .appendingPathComponent(sha1(of: url.absoluteString))
            .appendingPathComponent(name)
            .appendingPathExtension(pathExtension)
    }

    private static func sha1(of value: String) -> String {
        Insecure.SHA1
            .hash(data: Data(value.utf8))
            .prefix(Insecure.SHA1.byteCount)
            .hexEncoded()
    }
}

enum ImageType {
    case poster
    case album

    var size: CGSize {
        switch self {
        #if os(macOS)
            case .poster, .album: CGSize(width: 325, height: 488)
        #else
            case .poster, .album: CGSize(width: 250, height: 375)
        #endif
        }
    }

    var contentMode: ImageProcessingOptions.ContentMode {
        switch self {
        case .poster: .aspectFill
        case .album: .aspectFit
        }
    }

    var crop: Bool {
        switch self {
        case .poster: true
        case .album: false
        }
    }
}
