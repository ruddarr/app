import Nuke
import NukeUI

import SwiftUI

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
        if let url = url {
            LazyImage(
                request: Images.request(url, type, .veryHigh),
                transaction: .init(animation: .smooth)
            ) { state in
                if let image = state.image {
                    image.resizable().transition(
                        (try? state.result?.get())?.cacheType != nil ? .identity : .opacity
                    )
                } else if state.error != nil {
                    let _: Void = print(state.error.debugDescription)

                    PlaceholderImage(icon: "network.slash", text: nil)
                } else {
                    PlaceholderImage(icon: "text.below.photo", text: nil)
                }
            }.pipeline(
                Images.pipeline()
            )
        } else {
            PlaceholderImage(icon: "text.below.photo", text: placeholder)
        }
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
            }
            .frame(width: 200, height: 200)
        }
        .border(.yellow).padding()

        Section {
            HStack {
                CachedAsyncImage(.poster, "https://picsum.photos-broken/id/23/500/500", placeholder: "Fallback")
                    .frame(width: 100, height: 150)
                    .border(.green)
            }
            .frame(width: 200, height: 200)
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
                }
                .frame(width: 200, height: 200)
            }
            .border(.yellow)
            .background(.secondarySystemBackground)
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .border(.yellow)
}
