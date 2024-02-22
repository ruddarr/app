import os
import SwiftUI

struct MoviePreview: View {
    @Binding var movie: Movie

    @Environment(RadarrInstance.self) private var instance

    @State private var descriptionTruncated = true

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Text(movie.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .kerning(-0.5)

                HStack(spacing: 6) {
                    Text(String(movie.year))
                    Text("•")
                    Text(movie.runtimeLabel)

                    if movie.certification != nil {
                        Text("•")
                        Text(movie.certification ?? "")
                    }
                }
                .font(.callout)
                .foregroundStyle(.secondary)

                MovieDetailsRatings(movie: movie)
                    .padding(.bottom)

                description

                detailsGrid
            }
        }
        .scenePadding(.horizontal)
        .background(
            colorScheme == .dark
            ? .systemBackground
            : .secondarySystemBackground
        )
        .alert(
            "Something Went Wrong",
            isPresented: Binding(get: { instance.movies.error != nil }, set: { _ in }),
            presenting: instance.movies.error
        ) { _ in
            Button("OK", role: .cancel) { }
        } message: { error in
            Text(error.localizedDescription)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    MovieForm(movie: $movie)
                        .toolbar {
                            toolbarSaveButton
                        }
                } label: {
                    Text("Next")
                }
            }
        }
    }

    var description: some View {
        Text(movie.overview!)
            .font(.callout)
            .transition(.slide)
            .lineLimit(descriptionTruncated ? 4 : nil)
            .padding(.bottom)
            .onTapGesture {
                withAnimation { descriptionTruncated.toggle() }
            }
    }

    var detailsGrid: some View {
        Grid(alignment: .leading) {
            detailsRow("Status", value: movie.status.label)

            if let studio = movie.studio, !studio.isEmpty {
                detailsRow("Studio", value: studio)
            }

            if !movie.genres.isEmpty {
                detailsRow("Genre", value: movie.genreLabel)
            }
        }
        .padding(.bottom)
    }

    @ToolbarContentBuilder
    var toolbarSaveButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if instance.movies.isWorking {
                ProgressView().tint(.secondary)
            } else {
                Button("Add") {
                    Task {
                        await addMovie()
                    }
                }
            }
        }
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

    @MainActor
    func addMovie() async {
        guard await instance.movies.add(movie) else {
            leaveBreadcrumb(.error, category: "view.movie.preview", message: "Failed to add movie", data: ["error": instance.movies.error ?? ""])

            return
        }

        guard let addedMovie = instance.movies.byTmdbId(movie.tmdbId) else {
            fatalError("Failed to locate added movie by tmdbId")
        }

        let moviePath = MoviesView.Path.movie(addedMovie.id)

        dismiss()

        dependencies.router.moviesPath.removeLast(dependencies.router.moviesPath.count)
        dependencies.router.moviesPath.append(moviePath)
    }
}

#Preview {
    let movies: [Movie] = PreviewData.load(name: "movie-lookup")
    let movie = movies.first(where: { $0.id == 236 }) ?? movies[0]

    return MoviePreview(movie: Binding(get: { movie }, set: { _ in }))
        .withSettings()
        .withRadarrInstance(movies: movies)
}
