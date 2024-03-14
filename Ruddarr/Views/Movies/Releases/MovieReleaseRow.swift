import SwiftUI

struct MovieReleaseRow: View {
    var release: MovieRelease

    @State private var isShowingPopover = false

    var body: some View {
        linesStack
            .contentShape(Rectangle())
            .onTapGesture {
                isShowingPopover = true
            }
            .sheet(isPresented: $isShowingPopover) {
                MovieReleaseSheet(release: release)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.hidden)
            }
    }

    var linesStack: some View {
        VStack(alignment: .leading) {
            HStack(spacing: 4) {
                Text(release.cleanTitle)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
            }

            let secondaryOpacity = 0.65

            Group {
                HStack(spacing: 6) {
                    Text(release.qualityLabel)
                    Bullet()
                    Text(release.sizeLabel)
                    Bullet()
                    Text(release.ageLabel)
                }
                .opacity(secondaryOpacity)
                .lineLimit(1)

                HStack(spacing: 6) {
                    Text(release.typeLabel)
                        .foregroundStyle(peerColor)

                    Group {
                        Bullet()
                        Text(release.indexerLabel)
                    }.opacity(secondaryOpacity)

                    Spacer()

                    releaseIcon
                }
                .lineLimit(1)
            }
            .font(.subheadline)
        }
    }

    var releaseIcon: some View {
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
        switch release.seeders ?? 0 {
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
    dependencies.router.moviesPath.append(MoviesView.Path.movie(movie.id))
    dependencies.router.moviesPath.append(MoviesView.Path.releases(movie.id))

    return ContentView()
        .withSettings()
        .withRadarrInstance(movies: movies)
}
