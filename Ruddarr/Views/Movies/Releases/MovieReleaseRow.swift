import SwiftUI

struct MovieReleaseRow: View {
    var release: MovieRelease
    var movie: Movie

    @Environment(AppSettings.self) private var settings

    var body: some View {
        switch settings.releaseLayout {
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

                compactReleaseIcons
            }
            .lineLimit(1)
            .font(.subheadline)
        }
        .contentShape(Rectangle())
    }

    var detailedRow: some View {
        // swiftlint:disable:next closure_body_length
        VStack(alignment: .leading) {
            if !release.flagLabels.isEmpty {
                HStack(alignment: .top, spacing: 2) {
                    Text(release.flagLabels.joined(separator: "  "))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .tracking(1.1)
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer()

                    if release.rejected {
                        rejectedIcon
                    }
                }
            }

            HStack(alignment: .top, spacing: 2) {
                Text(release.title.breakable(minimumTail: 10))
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                if release.rejected && release.flagLabels.isEmpty {
                    rejectedIcon
                }
            }

            HStack(spacing: 6) {
                Text(release.qualityLabel)
                Bullet()
                Text(release.sizeLabel)

                if let bitrate = release.bitrateLabel(movie.runtime) {
                    Bullet()
                    Text(bitrate)
                }
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
                    Text(release.ageLabel)
                    Bullet()
                    Text(release.indexerLabel)
                }
                .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .font(.subheadline)

            CustomFormats(release.formatLabels)
        }
        .contentShape(Rectangle())
    }

    var rejectedIcon: some View {
        Image(systemName: "exclamationmark.square")
            .symbolVariant(.fill)
            .font(.subheadline)
            .imageScale(.medium)
            .foregroundStyle(.secondary)
    }

    var compactReleaseIcons: some View {
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

            if release.hasNonFreeleechFlags {
                Image(systemName: "flag.square")
            }

            if release.rejected {
                Image(systemName: "exclamationmark.square")
            }
        }
        .symbolVariant(.fill)
        .imageScale(.medium)
        .foregroundStyle(.secondary)
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
