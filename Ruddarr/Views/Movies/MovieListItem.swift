import SwiftUI

struct MovieListItem: View {
    var movie: Movie

    // content.frame(width: UIScreen.main.bounds.width * 0.4)

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            poster
                .frame(width: 80)

            VStack(alignment: .leading) {
                Text(movie.title)
                    .lineLimit(1)
                    .font(.headline)
                    .padding(.top, 6)

                HStack {
                    Text(movie.yearLabel)

                    if let runtime = movie.runtimeLabel {
                        Bullet()
                        Text(runtime)
                    }

                    Bullet()
                    Text(movie.certificationLabel)
                }
                .lineLimit(1)
                .font(.subheadline)

                Spacer()

                icons
                    .padding(.bottom, 6)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(.secondarySystemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .contextMenu {
            MovieContextMenu(movie: movie)
        } preview: {
            poster.frame(width: 300, height: 450)
        }
    }

    var poster: some View {
        CachedAsyncImage(.poster, movie.remotePoster, placeholder: movie.title)
            .aspectRatio(
                CGSize(width: 150, height: 225),
                contentMode: .fill
            )
    }

    var icons: some View {
        HStack {
            Image(systemName: "bookmark")
                .symbolVariant(movie.monitored ? .fill : .none)
                .imageScale(Self.gridIconScale())

            Group {
                if movie.isDownloaded {
                    Image(systemName: "checkmark").symbolVariant(.circle.fill)
                } else if movie.isWaiting {
                    Image(systemName: "clock")
                } else if movie.monitored {
                    Image(systemName: "xmark").symbolVariant(.circle)
                }
            }
            .imageScale(Self.gridIconScale())
        }
        .font(.body)
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
                return [GridItem(.adaptive(minimum: 300, maximum: 350), spacing: 12)]
            }

            return [GridItem(.adaptive(minimum: 300, maximum: 350), spacing: 20)]
        #endif
    }
}

#Preview {
    let movies: [Movie] = PreviewData.load(name: "movies")
        .sorted { $0.year > $1.year }

    let gridItemLayout = [
        GridItem(.adaptive(minimum: 300, maximum: 350), spacing: 12)
    ]

    return ScrollView {
        LazyVGrid(columns: gridItemLayout, spacing: 12) {
            ForEach(movies) { movie in
                MovieListItem(movie: movie)
            }
        }
        .padding(.top, 0)
        .viewPadding(.horizontal)
    }
    .withAppState()
}
