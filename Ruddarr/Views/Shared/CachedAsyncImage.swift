import Nuke
import NukeUI

import SwiftUI

struct CachedAsyncImage: View {
    let url: String?

    var body: some View {
        if url == nil {
            PlaceholderImage(icon: "text.below.photo")
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
            name: "com.github.radarr.DataCache"
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
                    size: CGSize(width: 50, height: 75),
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
            .foregroundColor(.secondary)
            .frame(maxWidth: /*@START_MENU_TOKEN@*/.infinity/*@END_MENU_TOKEN@*/, maxHeight: /*@START_MENU_TOKEN@*/.infinity/*@END_MENU_TOKEN@*/)
            .background(
                Color(UIColor.tertiarySystemBackground)
            )
    }
}

#Preview {
    VStack {
        Section {
            HStack {
                CachedAsyncImage(url: "https://picsum.photos/id/23/500/500")
                    .frame(width: 100, height: 150)
                    .border(.green)
            }.frame(width: 250, height: 250)
        }.border(.yellow).padding()

        Section {
            HStack {
                CachedAsyncImage(url: "https://picsum.photos-broken/id/23/500/500")
                    .frame(width: 100, height: 150)
                    .border(.green)
            }.frame(width: 250, height: 250)
        }.border(.yellow)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .border(.yellow)
}
