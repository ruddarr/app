import SwiftUI

struct MovieReleasesView: View {
    @Binding var movie: Movie

    @State private var sort: MovieReleaseSort = .init()

    @State private var fetched: Bool = false
    @State private var waitingTextOpacity: Double = 0

    @Environment(RadarrInstance.self) private var instance

    var body: some View {
        Group {
            List {
                ForEach(displayedReleases) { release in
                    MovieReleaseRow(release: release)
                }
            }
            .listStyle(.inset)
        }
        .toolbar {
            toolbarButtons
        }
        .task {
            guard !fetched else { return }

            await instance.releases.search(movie)

            fetched = true
        }
        .alert(
            "Something Went Wrong",
            isPresented: Binding(get: { instance.releases.error != nil }, set: { _ in }),
            presenting: instance.releases.error
        ) { _ in
            Button("OK", role: .cancel) { }
        } message: { error in
            Text(error.localizedDescription)
        }
        .overlay {
            if instance.releases.isSearching {
                ProgressView {
                    VStack {
                        Text("Searching...")
                        Text("Hold on, this may take a moment.")
                            .font(.footnote)
                            .opacity(waitingTextOpacity)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                    withAnimation { waitingTextOpacity = 1 }
                                }
                            }
                    }
                }.tint(.secondary)
            } else if instance.releases.items.isEmpty {
                ContentUnavailableView(
                    "No Releases Found",
                    systemImage: "slash.circle",
                    description: Text("Radarr found no releases for \"\(movie.title)\".")
                )
            }
        }
    }

    var displayedReleases: [MovieRelease] {
        var sortedReleases = instance.releases.items.sorted(
            by: sort.option.isOrderedBefore
        )

        if sort.indexer != ".all" {
            sortedReleases = sortedReleases.filter { $0.indexerLabel == sort.indexer }
        }

        if sort.quality != ".all" {
            sortedReleases = sortedReleases.filter { $0.quality.quality.name == sort.quality }
        }

        if sort.approvedOnly {
            sortedReleases = sortedReleases.filter { !$0.rejected }
        }

        if sort.freeleechOnly {
            sortedReleases = sortedReleases.filter {
                $0.cleanIndexerFlags.contains(where: { $0.localizedStandardContains("freeleech") })
            }
        }

        return sort.isAscending ? sortedReleases : sortedReleases.reversed()
    }
}

extension MovieReleasesView {
    @ToolbarContentBuilder
    var toolbarButtons: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            HStack {
                toolbarSortingButton
                toolbarFilterButton
            }
        }
    }

    var toolbarFilterButton: some View {
        Menu("Filters", systemImage: "line.3.horizontal.decrease") {
            indexersPicker

            qualityPicker

            Section {
                Toggle("Only Approved", isOn: $sort.approvedOnly)
                Toggle("Only FreeLeech", isOn: $sort.freeleechOnly)
            }
        }
    }

    var toolbarSortingButton: some View {
        Menu {
            Section {
                Picker("Sorting options", selection: $sort.option) {
                    ForEach(MovieReleaseSort.Option.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }.onChange(of: sort.option) {
                    switch sort.option {
                    case .byWeight: sort.isAscending = false
                    case .byAge: sort.isAscending = true
                    case .bySize: sort.isAscending = true
                    case .bySeeders: sort.isAscending = false
                    }
                }
            }

            Section {
                Picker("Sorting direction", selection: $sort.isAscending) {
                    Text("Ascending").tag(true)
                    Text("Descending").tag(false)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .imageScale(.medium)
        }
    }

    var indexersPicker: some View {
        Menu("Indexer") {
            Picker("Indexer", selection: $sort.indexer) {
                ForEach(indexers, id: \.self) { indexer in
                    Text(indexer).tag(Optional.some(indexer))
                }

                Text("All Indexers").tag(".all")
            }
        }
    }

    var qualityPicker: some View {
        Menu("Quality Profile") {
            Picker("Quality Profile", selection: $sort.quality) {
                ForEach(qualities, id: \.self) { quality in
                    Text(quality).tag(Optional.some(quality))
                }

                Text("All Quality Profiles").tag(".all")
            }
        }
    }

    var indexers: [String] {
        var seen: Set<String> = []

        return instance.releases.items
            .map { $0.indexerLabel }
            .filter { seen.insert($0).inserted }
            .sorted()
    }

    var qualities: [String] {
        var seen: Set<String> = []

        return instance.releases.items
            .map { $0.quality.quality.name ?? "Unknown" }
            .filter { seen.insert($0).inserted }
            .sorted()
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
