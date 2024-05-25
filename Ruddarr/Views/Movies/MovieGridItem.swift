import SwiftUI

struct MovieGridItem: View {
    @EnvironmentObject var settings: AppSettings
    var movie: Movie

    var body: some View {
        switch settings.layout {
        case .compact:
            poster
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contextMenu {
                    MovieContextMenu(movie: movie)
                } preview: {
                    poster.frame(width: 300, height: 450)
                }
                .background(.secondarySystemBackground)
                .overlay(alignment: .bottom) {
                    if movie.exists {
                        posterOverlay
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
        case .expanded:
            VStack {
                poster
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contextMenu {
                        MovieContextMenu(movie: movie)
                    } preview: {
                        poster.frame(width: 300, height: 450)
                    }
                    .background(.secondarySystemBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                Group {
                    Text(movie.title).font(.footnote).fontWeight(.medium)
                    HStack(spacing: 4) {
                        Group {
                            if movie.isDownloaded {
                                Image(systemName: "checkmark").symbolVariant(.circle.fill)
                            } else if movie.isWaiting {
                                Image(systemName: "clock")
                            } else if movie.monitored {
                                Image(systemName: "xmark").symbolVariant(.circle)
                            }
                        }.font(.caption)
                        Text(movie.monitored ? "Monitored" : "Unmonitored").font(.footnote)
                    }.foregroundStyle(.secondary).opacity(0.8)
                }.frame(maxWidth: .infinity, alignment: .leading).lineLimit(1)
            }
        }
    }

    var poster: some View {
        CachedAsyncImage(.poster, movie.remotePoster, placeholder: movie.title)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .aspectRatio(
                CGSize(width: 150, height: 225),
                contentMode: .fill
            )
    }

    var posterOverlay: some View {
        HStack {
            Group {
                if movie.isDownloaded {
                    Image(systemName: "checkmark").symbolVariant(.circle.fill)
                } else if movie.isWaiting {
                    Image(systemName: "clock")
                } else if movie.monitored {
                    Image(systemName: "xmark").symbolVariant(.circle)
                }
            }
                .foregroundStyle(.white)
                .imageScale(MovieGridItem.gridIconScale())

            Spacer()

            Image(systemName: "bookmark")
                .symbolVariant(movie.monitored ? .fill : .none)
                .foregroundStyle(.white)
                .imageScale(MovieGridItem.gridIconScale())
        }
        .font(.body)
        .padding(.top, 36)
        .padding(.bottom, 8)
        .padding(.horizontal, 8)
        .background {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.0),
                    Color.black.opacity(0.2),
                    Color.black.opacity(0.4),
                    Color.black.opacity(0.9),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    static func gridIconScale() -> Image.Scale {
        #if os(macOS)
            return .large
        #else
            if UIDevice.current.userInterfaceIdiom == .phone {
                return .small
            }

            return .medium
        #endif
    }

    static func gridItemSpacing() -> CGFloat {
        #if os(macOS)
            return 20
        #else
            if UIDevice.current.userInterfaceIdiom == .phone {
                return 12
            }

            return 20
        #endif
    }

    static func gridItemLayout() -> [GridItem] {
        #if os(macOS)
            return [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 20)]
        #else
            if UIDevice.current.userInterfaceIdiom == .phone {
                return [GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 12)]
            }

            return [GridItem(.adaptive(minimum: 145, maximum: 180), spacing: 20)]
        #endif
    }
}

#Preview {
    let movies: [Movie] = PreviewData.load(name: "movies")
        .sorted { $0.year > $1.year }

    let gridItemLayout = [
        GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 12)
    ]

    return ScrollView {
        LazyVGrid(columns: gridItemLayout, spacing: 12) {
            ForEach(movies) { movie in
                MovieGridItem(movie: movie)
            }
        }
        .padding(.top, 0)
        .viewPadding(.horizontal)
    }
    .withAppState()
}
