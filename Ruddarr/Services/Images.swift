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
        _ url: String,
        _ type: ImageType,
        _ priority: ImageRequest.Priority = .normal
    ) -> ImageRequest {
        ImageRequest(
            urlRequest: URLRequest(
                url: URL(string: url)!,
                timeoutInterval: 5
            ),
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

        let pipeline = Images.pipeline()
        let request = Images.request(poster, .poster, priority)

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

    private static func thumbnailPath(_ key: String) -> URL {
        let cacheKeyHash = Insecure.SHA1
            .hash(data: key.data(using: .utf8)!)
            .prefix(Insecure.SHA1.byteCount)
            .map { String(format: "%02hhx", $0) }
            .joined()

        return FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)
            .first!
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
