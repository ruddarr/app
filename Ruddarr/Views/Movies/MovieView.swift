import SwiftUI
import TelemetryDeck

struct MovieView: View {
    @Binding var movie: Movie

    @EnvironmentObject var settings: AppSettings

    @Environment(\.deviceType) private var deviceType
    @Environment(RadarrInstance.self) private var instance

    @State private var showEditForm: Bool = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        ScrollView {
            MovieDetails(movie: movie)
                .padding(.top)
                .viewPadding(.horizontal)
                .environmentObject(settings)
        }
        .refreshable {
            await Task { await reload() }.value
        }
        .safeNavigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarMonitorButton
            toolbarMenu
        }
        .onBecomeActive {
            await reload()
        }
        .alert(
            isPresented: instance.movies.errorBinding,
            error: instance.movies.error
        ) { _ in
            Button("OK") { instance.movies.error = nil }
        } message: { error in
            Text(error.recoverySuggestionFallback)
        }.tint(nil)
        .sheet(isPresented: $showDeleteConfirmation) {
            MediaDeleteSheet(label: "Delete Movie") { exclude, delete in
                Task {
                    await deleteMovie(exclude: exclude, delete: delete)
                    showDeleteConfirmation = false
                }
            }
            .presentationDetents(dynamic: [deviceType == .phone ? .fraction(0.33) : .medium])
        }
    }

    @ToolbarContentBuilder
    var toolbarMonitorButton: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Button {
                Task { await toggleMonitor() }
            } label: {
                ToolbarMonitorButton(monitored: $movie.monitored)
            }
            .allowsHitTesting(!instance.movies.isWorking)
            #if os(iOS)
                .buttonStyle(.plain)
            #endif
        }
    }

    @ToolbarContentBuilder
    var toolbarMenu: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Section {
                    refreshAction
                }

                openInLinks

                Section {
                    editAction
                    deleteMovieButton
                }
            } label: {
                ToolbarActionButton()
            }
            .tint(.primary)
            .menuIndicator(.hidden)
            #if os(macOS)
                .sheet(isPresented: $showEditForm) {
                    MovieEditView(movie: $movie)
                        .environment(instance)
                        .padding(.top)
                        .padding(.all)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { showEditForm = false }
                            }
                        }
                }
            #endif
        }
    }

    var refreshAction: some View {
        Button("Refresh", systemImage: "arrow.triangle.2.circlepath") {
            Task { await refresh() }
        }
    }

    var editAction: some View {
        #if os(macOS)
            Button("Edit") {
                showEditForm = true
            }
        #else
            NavigationLink(
                value: MoviesPath.edit(movie.id)
            ) {
                Label("Edit", systemImage: "pencil")
            }
        #endif
    }

    var openInLinks: some View {
        Section {
            if let trailerUrl = MovieLinks.youTubeTrailer(movie.youTubeTrailerId) {
                Link(destination: trailerUrl, label: {
                    Label("Watch Trailer", systemImage: "play")
                })
            }

            MovieLinks(movie: movie)
        }
    }

    var deleteMovieButton: some View {
        Button("Delete", systemImage: "trash", role: .destructive) {
            showDeleteConfirmation = true
        }.tint(.red)
    }
}

extension MovieView {
    func toggleMonitor() async {
        movie.monitored.toggle()

        guard await instance.movies.update(movie) else {
            return
        }

        dependencies.toast.show(movie.monitored ? .monitored : .unmonitored)
    }

    func reload() async {
        _ = await instance.movies.get(movie)
    }

    func refresh() async {
        guard await instance.movies.command(.refreshMovie([movie.id])) else {
            return
        }

        dependencies.toast.show(.refreshQueued)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            Task { await instance.movies.get(movie) }
        }
    }

    func dispatchSearch() async {
        guard await instance.movies.command(.search([movie.id])) else {
            return
        }

        dependencies.toast.show(.movieSearchQueued)

        TelemetryDeck.signal("automaticSearchDispatched", parameters: ["type": "movie"])
        maybeAskForReview()
    }

    func deleteMovie(exclude: Bool, delete: Bool) async {
        _ = await instance.movies.delete(movie, addExclusion: exclude, deleteFiles: delete)

        if !dependencies.router.moviesPath.isEmpty {
            dependencies.router.moviesPath.removeLast()
        }

        dependencies.toast.show(.movieDeleted)
    }
}

#Preview {
    let movies: [Movie] = PreviewData.load(name: "movies")
    let movie = movies.first(where: { $0.id == 235 }) ?? movies[0]

    dependencies.router.selectedTab = .movies

    dependencies.router.moviesPath.append(
        MoviesPath.movie(movie.id)
    )

    return ContentView()
        .withRadarrInstance(movies: movies)
        .withAppState()
}
