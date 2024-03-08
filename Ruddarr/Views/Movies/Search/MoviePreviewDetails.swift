import SwiftUI

struct MoviePreviewDetails: View {
    var movie: Movie

    @State private var descriptionTruncated = UIDevice.current.userInterfaceIdiom == .phone ? true : false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(movie.title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .kerning(-0.5)

            HStack(spacing: 6) {
                Text(String(movie.year))

                if let runtime = movie.runtimeLabel {
                    Bullet()
                    Text(runtime)
                }

                Bullet()
                Text(movie.certificationLabel)
            }
            .font(.callout)
            .foregroundStyle(.secondary)

            MovieRatings(movie: movie)
                .padding(.bottom)

            if let text = movie.overview, !text.trimmingCharacters(in: .whitespaces).isEmpty {
                description
            }

            actions

            detailsGrid
        }
        .viewPadding(.horizontal)
    }

    var description: some View {
        Text(movie.overview!)
            .font(.callout)
            .transition(.slide)
            .lineLimit(descriptionTruncated ? 4 : nil)
            .padding(.bottom)
            .onTapGesture {
                withAnimation { descriptionTruncated = false }
            }
    }

    var detailsGrid: some View {
        Grid(alignment: .leading) {
            if let studio = movie.studio, !studio.isEmpty {
                detailsRow(String(localized: "Studio"), value: studio)
            }

            if !movie.genres.isEmpty {
                detailsRow(String(localized: "Genre"), value: movie.genreLabel)
            }

            detailsRow(String(localized: "Status"), value: movie.status.label)
        }
        .padding(.bottom)
    }

    func detailsRow(_ label: String, value: String) -> some View {
        GridRow(alignment: .top) {
            Text(label)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .fontWeight(.medium)
                .padding(.trailing)
            Text(value)
            Spacer()
        }
        .font(.callout)
    }

    var actions: some View {
        HStack(spacing: 24) {
            if let trailerUrl = MovieContextMenu.youTubeTrailer(movie.youTubeTrailerId) {
                Button {
                    UIApplication.shared.open(URL(string: trailerUrl)!)
                } label: {
                    let label = UIDevice.current.userInterfaceIdiom == .phone
                        ? String(localized: "Trailer")
                        : String(localized: "Watch Trailer")

                    ButtonLabel(text: label, icon: "play.fill")
                        .modifier(MoviePreviewActionModifier())
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
            }

            Menu {
                MovieContextMenu(movie: movie)
            } label: {
                ButtonLabel(text: String(localized: "Open in"), icon: "arrow.up.right.square")
                    .modifier(MoviePreviewActionModifier())
            }
            .buttonStyle(.bordered)
            .tint(.secondary)

        }
        .padding(.bottom)
    }
}

struct MoviePreviewActionModifier: ViewModifier {
    func body(content: Content) -> some View {
        if UIDevice.current.userInterfaceIdiom == .phone {
            content.frame(maxWidth: .infinity)
        } else {
            content.frame(maxWidth: 215)
        }
    }
}

#Preview {
    let movies: [Movie] = PreviewData.load(name: "movie-lookup")
    let movie = movies.first(where: { $0.tmdbId == 1 }) ?? movies[0]

    return MoviePreviewSheet(movie: movie)
        .withAppState()
}
