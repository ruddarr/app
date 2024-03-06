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
                    Text("•")
                    Text(runtime)
                }

                if movie.certification != nil {
                    Text("•")
                    Text(movie.certification ?? "")
                }
            }
            .font(.callout)
            .foregroundStyle(.secondary)

            MovieRatings(movie: movie)
                .padding(.bottom)

            description

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
                detailsRow("Studio", value: studio)
            }

            if !movie.genres.isEmpty {
                detailsRow("Genre", value: movie.genreLabel)
            }

            detailsRow("Status", value: movie.status.label)
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
}

#Preview {
    let movies: [Movie] = PreviewData.load(name: "movie-lookup")
    let movie = movies.first(where: { $0.id == 5 }) ?? movies[0]

    return MoviePreviewSheet(movie: movie)
        .withAppState()
}
