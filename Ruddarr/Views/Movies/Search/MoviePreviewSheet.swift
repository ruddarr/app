import os
import SwiftUI

struct MoviePreviewSheet: View {
    @State var movie: Movie

    @EnvironmentObject var settings: AppSettings
    @Environment(RadarrInstance.self) private var instance

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                MoviePreviewDetails(movie: movie)
            }
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
                if error.localizedDescription == "cancelled" {
                    let _ = leaveBreadcrumb(.error, category: "cancelled", message: "MoviePreview") // swiftlint:disable:this redundant_discardable_let
                }

                Text(error.localizedDescription)
            }
            .toolbar {
                toolbarCancelButton
                toolbarNextButton
            }
        }
    }

    @ToolbarContentBuilder
    var toolbarCancelButton: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Cancel", action: {
                dismiss()
            })
        }
    }

    @ToolbarContentBuilder
    var toolbarNextButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            NavigationLink("Next") {
                MovieForm(movie: $movie)
                    .toolbar {
                        toolbarSaveButton
                    }
            }
        }
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

    @MainActor
    func addMovie() async {
        guard await instance.movies.add(movie) else {
            leaveBreadcrumb(.error, category: "view.movie.preview", message: "Failed to add movie", data: ["error": instance.movies.error ?? ""])

            return
        }

        guard let addedMovie = instance.movies.byTmdbId(movie.tmdbId) else {
            fatalError("Failed to locate added movie by tmdbId")
        }

        instance.lookup.reset()

        let moviePath = MoviesView.Path.movie(addedMovie.id)

        dismiss()

        dependencies.router.moviesPath.removeLast(dependencies.router.moviesPath.count)
        dependencies.router.moviesPath.append(moviePath)
    }
}

#Preview {
    let movies: [Movie] = PreviewData.load(name: "movie-lookup")
    let movie = movies.first(where: { $0.tmdbId == 736308 }) ?? movies[0]

    return MoviePreviewSheet(movie: movie)
        .withAppState()
}
