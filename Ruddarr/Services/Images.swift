import Nuke
import Foundation

class Images {
    static let cacheName: String = "com.ruddarr.images"

    static func pipeline() -> ImagePipeline {
        var config = ImagePipeline.Configuration.withDataCache(name: cacheName)
        config.dataCachePolicy = .automatic

        return ImagePipeline(configuration: config)
    }

    static func request(_ url: String, _ type: ImageType) -> ImageRequest {
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
            ]
        )
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
