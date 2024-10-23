import SwiftUI
import TelemetryDeck

struct MoviePreviewView: View {
    @State var movie: Movie

    @State private var presentingForm: Bool = false

    @Environment(RadarrInstance.self) private var instance
    @Environment(\.dismiss) private var dismiss
    @Environment(\.deviceType) private var deviceType

    @AppStorage("movieSort", store: dependencies.store) var movieSort: MovieSort = .init()
    @AppStorage("movieDefaults", store: dependencies.store) var movieDefaults: MovieDefaults = .init()

    var body: some View {
        ScrollView {
            MovieDetails(movie: movie)
                .padding(.top)
                .viewPadding(.horizontal)
        }
        .safeNavigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarNextButton
        }
        .sheet(isPresented: $presentingForm) {
            NavigationStack {
                MovieForm(movie: $movie)
                    .padding(.top, -25)
                    .toolbar {
                        toolbarCancelButton
                        toolbarSaveButton
                    }
            }
            .presentationDetents([deviceType == .phone ? .medium : .large])
        }
        .alert(
            isPresented: instance.movies.errorBinding,
            error: instance.movies.error
        ) { _ in
            Button("OK") { instance.movies.error = nil }
        } message: { error in
            Text(error.recoverySuggestionFallback)
        }
    }

    @ToolbarContentBuilder
    var toolbarCancelButton: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                presentingForm = false
            }
        }
    }

    @ToolbarContentBuilder
    var toolbarNextButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button("Add Movie") {
                presentingForm = true
            }
        }
    }

    @ToolbarContentBuilder
    var toolbarSaveButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if instance.movies.isWorking {
                ProgressView().tint(.secondary)
            } else {
                Button("Add Movie") {
                    Task {
                        await addMovie()
                    }
                }
            }
        }
    }

    @MainActor
    func addMovie() async {
        movieDefaults = .init(from: movie)

        guard await instance.movies.add(movie) else {
            leaveBreadcrumb(.error, category: "view.movie.preview", message: "Failed to add movie", data: ["error": instance.movies.error ?? ""])

            return
        }

        guard let addedMovie = instance.movies.byTmdbId(movie.tmdbId) else {
            fatalError("Failed to locate added movie by TMDB id")
        }

        #if os(iOS)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif

        presentingForm = false
        movieSort.filter = .all

        let moviePath = MoviesPath.movie(addedMovie.id)
        dependencies.router.moviesPath.removeLast()
        dependencies.router.moviesPath.append(moviePath)

        TelemetryDeck.signal("movieAdded")
        maybeAskForReview()
    }
}

#Preview {
    let movies: [Movie] = PreviewData.load(name: "movie-lookup")
    let movie = movies.first(where: { $0.tmdbId == 736_308 }) ?? movies[0]

    dependencies.router.selectedTab = .movies

    dependencies.router.moviesPath.append(
        MoviesPath.preview(
            try? JSONEncoder().encode(movie)
        )
    )

    return ContentView()
        .withRadarrInstance(movies: movies)
        .withAppState()
}
