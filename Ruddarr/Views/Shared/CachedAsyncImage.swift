import Nuke
import NukeUI

import SwiftUI

enum ImageType {
    case poster
    case header

    var size: CGSize {
        switch self {
        case .poster: CGSize(width: 120, height: 180)
        case .header: CGSize(width: 320, height: 180)
        }
    }
}

struct CachedAsyncImage: View {
    let url: String?
    let type: ImageType

    var body: some View {
        if url == nil {
            Rectangle()
                .fill(Color(UIColor.systemFill))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            LazyImage(request: imageRequest(url)) { state in
                if let image = state.image {
                    image.resizable()
                } else if state.error != nil {
                    let _: Void = print(state.error.debugDescription)

                    PlaceholderImage(icon: "network.slash")
                } else {
                    PlaceholderImage(icon: "text.below.photo")
                }
            }.pipeline(imagePipeline())
        }
    }

    func imagePipeline() -> ImagePipeline {
        var config = ImagePipeline.Configuration.withDataCache(
            name: "com.ruddarr.images"
        )

        config.dataCachePolicy = .automatic

        return ImagePipeline(configuration: config)
    }

    func imageRequest(_ urlString: String?) -> ImageRequest {
        let url = URL(string: urlString!)
        let request = URLRequest(url: url!, timeoutInterval: 5)
        // request.addValue("test", forHTTPHeaderField: "X-Api-Key")

        return ImageRequest(
            urlRequest: request,
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

struct PlaceholderImage: View {
    let icon: String

    var body: some View {
        Image(systemName: icon)
            .imageScale(.large)
            .foregroundStyle(.secondary)
            .frame(maxWidth: /*@START_MENU_TOKEN@*/.infinity/*@END_MENU_TOKEN@*/, maxHeight: /*@START_MENU_TOKEN@*/.infinity/*@END_MENU_TOKEN@*/)
            .background(
                Color(UIColor.systemFill)
            )
    }
}

#Preview {
    VStack {
        Section {
            HStack {
                CachedAsyncImage(url: "https://picsum.photos/id/23/500/500", type: .poster)
                    .frame(width: 100, height: 150)
                    .border(.green)
            }.frame(width: 250, height: 250)
        }
        .border(.yellow).padding()

        Section {
            HStack {
                CachedAsyncImage(url: "https://picsum.photos-broken/id/23/500/500", type: .poster)
                    .frame(width: 100, height: 150)
                    .border(.green)
            }.frame(width: 250, height: 250)
        }
        .border(.yellow)
        .background(.secondarySystemBackground)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .border(.yellow)
}
