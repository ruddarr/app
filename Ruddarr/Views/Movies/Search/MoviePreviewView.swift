import SwiftUI
import TelemetryDeck

struct MoviePreviewView: View {
    @State var movie: Movie

    @State private var presentingForm: Bool = false
    @State private var isHydrating: Bool = false

    @EnvironmentObject var settings: AppSettings

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
                .environmentObject(settings)
        }
        .safeNavigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarNextButton
        }
        .alert(
            isPresented: instance.movies.errorBinding,
            error: instance.movies.error
        ) { _ in
            Button("OK") { instance.movies.error = nil }
        } message: { error in
            Text(error.recoverySuggestionFallback)
        }.tint(nil)
        .task {
            await hydrateFromRadarrIfNeeded()
        }
        .sheet(isPresented: $presentingForm) {
            NavigationStack {
                MovieForm(movie: $movie)
                    .toolbar {
                        toolbarCancelButton
                        toolbarSaveButton
                    }
                    #if os(macOS)
                        .padding(.all)
                    #else
                        .padding(.top, -25)
                    #endif
            }
            .presentationDetents(dynamic: [deviceType == .phone ? .medium : .large])
            .presentationBackground(.ultraThinMaterial)
        }
    }

    @ToolbarContentBuilder
    var toolbarCancelButton: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button {
                presentingForm = false
            } label: {
                Label("Cancel", systemImage: "xmark")
            }
            .tint(.primary)
        }
    }

    @ToolbarContentBuilder
    var toolbarNextButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button("Add Movie", systemImage: "plus") {
                presentingForm = true
            }
            .buttonStyle(.glassProminent)
            .disabled(presentingForm)
        }
    }

    @ToolbarContentBuilder
    var toolbarSaveButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                Task {
                    await addMovie()
                }
            } label: {
                if instance.movies.isWorking {
                    ProgressView().tint(nil)
                } else {
                    Label("Add Movie", systemImage: "checkmark")
                }
            }
            .prominentGlassButtonStyle(!instance.movies.isWorking)
            .disabled(instance.movies.isWorking)
        }
    }

    /// Hydrate only when the preview is opened to avoid bulk API calls
    func hydrateFromRadarrIfNeeded() async {
        guard !instance.isVoid,
              !isHydrating,
              !movie.exists,
              movie.tmdbId > 0 else { return }

        isHydrating = true
        defer { isHydrating = false }

        do {
            let results = try await dependencies.api.lookupMovies(instance.lookup.instance, "tmdbid:\(movie.tmdbId)")
            if let enriched = results.first(where: { $0.tmdbId == movie.tmdbId }) {
                movie = enriched
            }
        } catch {
            leaveBreadcrumb(.error, category: "movie.preview", message: "Hydrate failed", data: ["error": error.localizedDescription])
        }
    }

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

        if !dependencies.router.moviesPath.isEmpty {
            dependencies.router.moviesPath.removeLast()
        }

        try? await Task.sleep(for: .milliseconds(50))
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
