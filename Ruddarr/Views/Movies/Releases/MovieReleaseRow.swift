import SwiftUI

struct MovieReleaseRow: View {
    var release: MovieRelease
    var movie: Movie

    @Environment(AppSettings.self) private var settings

    var body: some View {
        switch settings.releases {
        case .compact: compactRow
        case .detailed: detailedRow
        }
    }

    var compactRow: some View {
        VStack(alignment: .leading) {
            Text(release.title)
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(1)

            HStack(spacing: 6) {
                Text(release.qualityLabel)
                Bullet()
                Text(release.sizeLabel)
                Bullet()
                Text(release.ageLabel)
            }
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .font(.subheadline)

            HStack(spacing: 6) {
                Text(release.typeLabel)
                    .foregroundStyle(peerColor)
                    .truncationMode(.head)

                Group {
                    Bullet()
                    Text(release.languageLabel)
                    Bullet()
                    Text(release.indexerLabel)
                }
                .foregroundStyle(.secondary)

                Spacer()

                releaseIcons
            }
            .lineLimit(1)
            .font(.subheadline)
        }
        .contentShape(Rectangle())
    }

    var detailedRow: some View {
        VStack(alignment: .leading) {
            titleRow
            qualityRow

            VStack(alignment: .leading, spacing: 6) {
                metadataRow
                formatsRow
            }
        }
        .contentShape(Rectangle())
    }

    var metadataRow: some View {
        HStack(spacing: 6) {
            Text(release.typeLabel)
                .foregroundStyle(peerColor)
                .truncationMode(.head)

            Group {
                Bullet()
                Text(release.languageLabel)
                Bullet()
                Text(release.ageLabel)
                Bullet()
                Text(release.indexerLabel)
            }
            .foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .font(.subheadline)
    }

    var titleRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(release.title.breakable(minimumTail: 8))
                .font(.headline)
                .fontWeight(.semibold)

            Spacer()

            releaseIcons
        }
    }

    var qualityRow: some View {
        HStack(spacing: 6) {
            Text(release.qualityLabel)
            Bullet()
            Text(release.sizeLabel)

            if let bitrate = release.bitrateLabel(movie.runtime) {
                Group {
                    Bullet()
                    Text(bitrate)
                }
                .layoutPriority(-1)
            }

            Spacer()
        }
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .font(.subheadline)
    }

    @ViewBuilder
    var formatsRow: some View {
        if !release.formatLabels.isEmpty {
            CustomFormats(release.formatLabels, small: true)
        }
    }

    @ViewBuilder
    var releaseIcons: some View {
        if !release.flagLabels.isEmpty || release.rejected {
            HStack(spacing: 2) {
                if release.isFreeleech {
                    Image(systemName: "f.square")
                }

                if release.isProper {
                    Image(systemName: "p.square")
                }

                if release.isRepack {
                    Image(systemName: "r.square")
                }

                if release.isNuked {
                    Image(systemName: "trash.square")
                }

                if release.hasOtherFlags {
                    Image(systemName: "flag.square")
                }

                if release.rejected {
                    Image(systemName: "exclamationmark.square")
                        .foregroundStyle(.orange)
                }
            }
            .symbolVariant(.fill)
            .imageScale(.medium)
            .foregroundStyle(.secondary)
            .font(
                settings.releases == .detailed ? .callout : .subheadline
            )
        }
    }

    var peerColor: any ShapeStyle {
        if release.isUsenet {
            return .green
        }

        if release.rejections.contains(where: { $0.contains("Not enough seeders") }) {
            return .red
        }

        return switch release.seeders ?? 0 {
        case 50...: .green
        case 10..<50: .blue
        case 1..<10: .orange
        default: .red
        }
    }
}

#Preview {
    let movies: [Movie] = PreviewData.load(name: "movies")
    let movie = movies.first(where: { $0.id == 66 }) ?? movies[0]

    dependencies.router.selectedTab = .movies
    dependencies.router.moviesPath.append(MoviesPath.movie(movie.id))
    dependencies.router.moviesPath.append(MoviesPath.releases(movie.id))

    return ContentView()
        .withRadarrInstance(movies: movies)
        .withAppState()
}
