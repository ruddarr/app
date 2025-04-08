import SwiftUI

struct MovieReleaseRow: View {
    var release: MovieRelease
    var movie: Movie

    @State private var isShowingPopover = false

    @EnvironmentObject var settings: AppSettings
    @Environment(\.deviceType) private var deviceType
    @Environment(RadarrInstance.self) private var instance

    var body: some View {
        linesStack
            .contentShape(Rectangle())
            .onTapGesture {
                isShowingPopover = true
            }
            .sheet(isPresented: $isShowingPopover) {
                MovieReleaseSheet(release: release, movie: movie)
                    .presentationDetents(dynamic: [deviceType == .phone ? .medium : .large])
                    .environment(instance)
                    .environmentObject(settings)
            }
    }

    var linesStack: some View {
        VStack(alignment: .leading) {
            Text(release.title)
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(1)

            secondRow
            thirdRow
        }
    }

    var secondRow: some View {
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
    }

    var thirdRow: some View {
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

    var releaseIcons: some View {
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
