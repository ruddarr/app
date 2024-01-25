import SwiftUI

struct MovieView: View {
    var instance: Instance
    var movie: Movie

    var body: some View {

        // movie.remoteFanart ???

        ScrollView {
            // MARK: overview
            HStack(alignment: .top) {
                CachedAsyncImage(url: movie.remotePoster)
                    .scaledToFit()
                    .frame(width: 130)
                    .clipped()
                    .cornerRadius(8)
                    .padding(.trailing, 8)

                Group {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(movie.title).font(/*@START_MENU_TOKEN@*/.title/*@END_MENU_TOKEN@*/).fontWeight(.bold)

                        HStack(spacing: 12) {
                            Text(movie.certification ?? "test")
                                .padding(.horizontal, 4)
                                .border(.secondary)

                            Text(String(movie.year))

                            Text(movie.humanRuntime)
                        }
                        .foregroundColor(.secondary)

                        HStack(spacing: 8) {
                            Image(systemName: movie.monitored ? "bookmark.fill" : "bookmark")
                            Text(movie.monitored ? "Monitored" : "Unmonitored")
                        }

                        // tvdb, imdb, rotten 2x

                        //                        HStack(spacing: 12) {
                        //                            Text(String(movie.year))
                        //                            Text(movie.humanRuntime)
                        //                        }
                        //                        .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .padding(.bottom)

            // MARK: description
            HStack(alignment: .top) {
                Text(movie.overview!).font(.callout)
                Spacer()
            }
            .padding(.bottom)

            // MARK: details
            Grid(alignment: .leading) {
                detailsRow("Studio", value: movie.studio!)
                detailsRow("Status", value: movie.status.rawValue)

                if !movie.genres.isEmpty {
                    detailsRow("Genre", value: movie.humanGenres)
                }
            }
            .padding(.bottom)

            // MARK: more details
            Grid(alignment: .leading) {
                detailsRow("Path", value: "")
                detailsRow("Quality", value: String(movie.qualityProfileId))

                if movie.sizeOnDisk != nil {
                    detailsRow("Size", value: movie.humanSize)
                }
            }
            .border(.gray)
            .padding(.bottom)

            // MARK: dates
            Grid(alignment: .leading) {
                if let inCinemas = movie.inCinemas {
                    detailsRow("In Cinemas", value: inCinemas.formatted(.dateTime.day().month().year()))
                }

                detailsRow("Physical Release", value: "")
                detailsRow("Digital Release", value: "")
            }
            .border(.gray)

            // Path
            // Status: Downloaded

            // Size
            // Resolution?

            // tba, announced, inCinemas, released, deleted

            //            Path
            //            /volume2/Media/Movies/Barbie (2023)
            //            Status
            //            Downloaded
            //            Quality Profile
            //            Ultra-HD (4K)
            //            Size
            //            19.8 GiB

        }
        .navigationBarTitleDisplayMode(.inline)
        .padding(.top)
        .padding(.horizontal)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(value: MoviesView.Path.edit(movie.id)) {
                    Text("Edit")
                }
            }
        }
    }

    func detailsRow(_ label: String, value: String) -> some View {
        GridRow {
            Text(label)
                .textCase(.uppercase)
                .foregroundColor(.secondary)
                .fontWeight(.medium)
                .padding(.trailing)
            Text(value)
            Spacer()
        }
        .font(.callout)
    }
}

#Preview {
    let movies: [Movie] = PreviewData.load(name: "movies")

    dependencies.router.selectedTab = .movies

    dependencies.router.moviesPath.append(
        MoviesView.Path.movie(movies[2].id)
    )

    return ContentView()
        .withSettings()
}
