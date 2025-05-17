import SwiftUI

struct MovieGridCard: View {
    var movie: Movie

    @Environment(\.deviceType) private var deviceType
    @Environment(RadarrInstance.self) private var instance

    var body: some View {
        HStack(alignment: .top, spacing: deviceType == .phone ? 10 : 14) {
            poster
                .frame(width: posterWidth)

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

    var posterWidth: CGFloat {
        deviceType == .phone ? 80 : 90
    }

    var icons: some View {
        HStack {
            let iconScale: Image.Scale = deviceType == .phone ? .small : .medium

            Image(systemName: "bookmark")
                .symbolVariant(movie.monitored ? .fill : .none)
                .imageScale(iconScale)

            Group {
                if movie.isDownloaded {
                    Image(systemName: "checkmark").symbolVariant(.circle)
                } else if movie.isWaiting {
                    Image(systemName: "clock")
                } else if movie.monitored {
                    Image(systemName: "xmark").symbolVariant(.circle)
                }
            }
            .imageScale(iconScale)
        }
        .font(.body)
        .foregroundStyle(.secondary)
    }

    var qualityProfile: String {
        instance.qualityProfiles.first(
            where: { $0.id == movie.qualityProfileId }
        )?.name ?? String(localized: "Unknown")
    }
}

#Preview {
    let movies: [Movie] = PreviewData.load(name: "movies")

    NavigationStack {
        ScrollView {
            MediaGrid(items: movies, style: .cards) { movie in
                MovieGridCard(movie: movie)
            }
            .viewPadding(.horizontal)
        }
        .withAppState()
    }
}
