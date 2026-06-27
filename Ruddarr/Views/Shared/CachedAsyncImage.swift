import SwiftUI
import Nuke
import NukeUI

struct CachedAsyncImage: View {
    let url: String?
    let type: ImageType
    let placeholder: String?
    let priority: ImageRequest.Priority

    init(
        _ type: ImageType,
        _ url: String?,
        placeholder: String? = nil,
        priority: ImageRequest.Priority = .normal
    ) {
        self.url = url
        self.type = type
        self.placeholder = placeholder
        self.priority = priority
    }

    var body: some View {
        if let imageUrl = URL(string: url ?? "") {
            LazyImage(
                request: Images.request(imageUrl, type, priority),
                transaction: .init(animation: .smooth)
            ) { state in
                if let image = state.image {
                    image.resizable().transition(
                        unsafe ((try? state.result?.get())?.cacheType != nil ? .identity : .opacity)
                    )
                // } else if state.error != nil {
                    // PlaceholderImage(text: placeholder, status: "network.slash")
                } else {
                    PlaceholderImage(text: placeholder)
                }
            }.pipeline(Images.shared)
        } else {
            PlaceholderImage(text: placeholder)
        }
    }
}

struct PlaceholderImage: View {
    let text: String?
    let status: String?

    init(text: String?, status: String? = nil) {
        self.text = text
        self.status = status
    }

    var body: some View {
        if let label = text, let icon = status {
            Rectangle()
                .fill(.systemFill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay {
                    Text(label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .tint(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                        .padding(8)
                }
                .overlay(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .foregroundStyle(.secondary)
                        .tint(.secondary)
                        .padding(8)
                }
        } else if let label = text {
            Rectangle()
                .fill(.systemFill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay {
                    Text(label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .tint(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                        .padding(8)
                }
        } else {
            Image(systemName: "text.below.photo")
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
        .background(.card)

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
            .background(.card)
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .border(.yellow)
}
