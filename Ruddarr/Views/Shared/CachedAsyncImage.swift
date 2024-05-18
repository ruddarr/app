import Nuke
import NukeUI

import SwiftUI

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

struct CachedAsyncImage: View {
    let url: String?
    let type: ImageType
    let placeholder: String?

    init(_ type: ImageType, _ url: String?, placeholder: String? = nil) {
        self.url = url
        self.type = type
        self.placeholder = placeholder
    }

    var body: some View {
        if url == nil {
            PlaceholderImage(icon: "text.below.photo", text: placeholder)
        } else {
            LazyImage(request: imageRequest(url)) { state in
                if let image = state.image {
                    image.resizable()
                } else if state.error != nil {
                    let _: Void = print(state.error.debugDescription)

                    PlaceholderImage(icon: "network.slash", text: nil)
                } else {
                    PlaceholderImage(icon: "text.below.photo", text: nil)
                }
            }.pipeline(
                imagePipeline()
            )
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
    let text: String?

    var body: some View {
        if let placeholder = text {
            Rectangle()
                .fill(.systemFill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay {
                    Text(placeholder)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .tint(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                        .padding(8)
                }
        } else {
            Image(systemName: icon)
                .imageScale(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .foregroundStyle(.secondary)
                .tint(.secondary)
                .background(.systemFill)
        }
    }
}

#Preview {
    VStack {
        Section {
            HStack {
                CachedAsyncImage(.poster, "https://picsum.photos/id/23/500/500", placeholder: "Fallback")
                    .frame(width: 100, height: 150)
                    .border(.green)
            }.frame(width: 200, height: 200)
        }
        .border(.yellow).padding()

        Section {
            HStack {
                CachedAsyncImage(.poster, "https://picsum.photos-broken/id/23/500/500", placeholder: "Fallback")
                    .frame(width: 100, height: 150)
                    .border(.green)
            }.frame(width: 200, height: 200)
        }
        .border(.yellow)
        .background(.secondarySystemBackground)

        NavigationStack {
            Section {
                HStack {
                    NavigationLink(destination: EmptyView()) {
                        CachedAsyncImage(.poster, nil, placeholder: "Aquaman and the Lost Kingdom")
                            .frame(width: 100, height: 150)
                            .border(.green)
                    }
                }.frame(width: 200, height: 200)
            }
            .border(.yellow)
            .background(.secondarySystemBackground)
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .border(.yellow)
}
