import Foundation
import CryptoKit
import Nuke

class Images {
    static let cacheName: String = "com.ruddarr.images"

    static func pipeline() -> ImagePipeline {
        var config = ImagePipeline.Configuration.withDataCache(name: cacheName)
        config.dataCachePolicy = .automatic

        return ImagePipeline(configuration: config)
    }

    static func request(
        _ url: URL,
        _ type: ImageType,
        _ priority: ImageRequest.Priority = .normal
    ) -> ImageRequest {
        ImageRequest(
            urlRequest: URLRequest(url: url, timeoutInterval: 5),
            processors: [
                .resize(
                    size: type.size,
                    contentMode: .aspectFill,
                    crop: true,
                    upscale: true
                )
            ],
            priority: priority
        )
    }

    static func thumbnail(_ poster: String?, _ priority: ImageRequest.Priority = .normal) async -> URL? {
        guard let poster = poster else { return nil }
        guard let url = URL(string: poster) else { return nil }

        let pipeline = self.pipeline()
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

    static func localCopy(of remote: String?, named filename: String? = nil) async -> URL? {
        guard let remote, let url = URL(string: remote) else { return nil }

        if let cached = hasLocalCopy(of: remote, named: filename) {
            return cached
        }

        let file = localCopyDestination(for: url, named: filename)

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            try data.write(to: file)
            return file
        } catch {
            return nil
        }
    }

    static func hasLocalCopy(of remote: String?, named filename: String? = nil) -> URL? {
        guard let remote, let url = URL(string: remote) else { return nil }

        let file = localCopyDestination(for: url, named: filename)

        return FileManager.default.fileExists(atPath: file.path) ? file : nil
    }

    private static func localCopyDestination(for url: URL, named filename: String?) -> URL {
        let pathExtension = url.pathExtension.isEmpty ? "jpg" : url.pathExtension

        let name = filename
            .map { sanitizeFilename($0) }
            .flatMap { $0.isEmpty ? nil : $0 }
            ?? url.deletingPathExtension().lastPathComponent

        return FileManager.default.temporaryDirectory
            .appendingPathComponent(name)
            .appendingPathExtension(pathExtension)
    }

    private static func sanitizeFilename(_ name: String) -> String {
        let illegal = CharacterSet(charactersIn: "/\\:*?\"<>|").union(.newlines)

        return name
            .components(separatedBy: illegal)
            .joined(separator: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    private static func thumbnailPath(_ key: String) -> URL? {
        let cacheKeyHash = Insecure.SHA1
            .hash(data: Data(key.utf8))
            .prefix(Insecure.SHA1.byteCount)
            .map { String(format: "%02hhx", $0) }
            .joined()

        return FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("com.ruddarr.images/\(cacheKeyHash)")
    }
}

enum ImageType {
    case poster

    var size: CGSize {
        switch self {
        #if os(macOS)
            case .poster: CGSize(width: 325, height: 488)
        #else
            case .poster: CGSize(width: 250, height: 375)
        #endif
        }
    }
}
