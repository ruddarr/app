import SwiftUI

struct MovieGridCard: View {
    var movie: Movie

    @Environment(\.deviceType) private var deviceType
    @Environment(RadarrInstance.self) private var instance

    var body: some View {
        HStack(alignment: .top, spacing: deviceType == .phone ? 10 : 14) {
            poster
                .frame(width: deviceType == .phone ? 80 : 95)

            VStack(alignment: .leading) {
                Text(movie.title)
                    .lineLimit(1)
                    .font(.headline)

                HStack(spacing: 6) {
                    Text(movie.yearLabel)

                    if let runtime = movie.runtimeLabel {
                        Bullet()
                        Text(runtime)
                    }

                    if let size = movie.sizeLabel {
                        Bullet()
                        Text(size)
                    }
                }
                .lineLimit(1)
                .font(.subheadline)
                .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    Text(qualityProfile)
                    Bullet()
                    Text(movie.minimumAvailability.label)
                }
                .lineLimit(1)
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Spacer()

                icons
            }
            .padding(.vertical, deviceType == .phone ? 8 : 10)

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
            let iconScale: Image.Scale = deviceType == .phone ? .small : .medium

            Image(systemName: "bookmark")
                .symbolVariant(movie.monitored ? .fill : .none)
                .imageScale(iconScale)

            Group {
                if movie.isDownloaded {
                    Image(systemName: "checkmark").symbolVariant(.circle.fill)
                } else if movie.isWaiting {
                    Image(systemName: "clock")
                } else if movie.monitored {
                    Image(systemName: "xmark").symbolVariant(.circle)
                }
            }
            .imageScale(iconScale)
        }
        .font(.body)
    }

    var qualityProfile: String {
        instance.qualityProfiles.first(
            where: { $0.id == movie.qualityProfileId }
        )?.name ?? String(localized: "Unknown")
    }

    static func gridItemLayout() -> [GridItem] {
        #if os(macOS)
            return [GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 20)]
        #else
            if UIDevice.current.userInterfaceIdiom == .phone {
                return [GridItem(.adaptive(minimum: 250, maximum: 400), spacing: 12)]
            }

            return [GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 20)]
        #endif
    }
}

#Preview {
    let movies: [Movie] = PreviewData.load(name: "movies")
        .sorted { $0.year > $1.year }

    return ScrollView {
        MediaGrid(items: movies, style: .cards) { movie in
            MovieGridCard(movie: movie)
        }
        .viewPadding(.horizontal)
    }
    .withAppState()
}
