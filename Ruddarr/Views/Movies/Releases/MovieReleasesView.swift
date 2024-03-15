import SwiftUI

struct MovieReleasesView: View {
    @Binding var movie: Movie

    @State private var sort: MovieReleaseSort = .init()

    @State private var fetched: Bool = false
    @State private var waitingTextOpacity: Double = 0

    @EnvironmentObject var settings: AppSettings
    @Environment(RadarrInstance.self) private var instance

    var body: some View {
        Group {
            List {
                ForEach(displayedReleases) { release in
                    MovieReleaseRow(release: release)
                        .environment(instance).environmentObject(settings)
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
            if error.localizedDescription == "cancelled" {
                let _ = leaveBreadcrumb(.error, category: "cancelled", message: "MovieReleasesView") // swiftlint:disable:this redundant_discardable_let
            }

            Text(error.localizedDescription)
        }
        .overlay {
            if instance.releases.isSearching {
                searchingIndicator
            } else if instance.releases.items.isEmpty {
                noReleasesFound
            } else if displayedReleases.isEmpty {
                noMatchingReleases
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
            sortedReleases = sortedReleases.filter { $0.quality.quality.normalizedName == sort.quality }
        }

        if sort.customFormat != ".all" {
            sortedReleases = sortedReleases.filter { $0.customFormats?.contains { $0.name == sort.customFormat } ?? false }
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

    var noReleasesFound: some View {
        ContentUnavailableView(
            "No Releases Found",
            systemImage: "slash.circle",
            description: Text("Radarr found no releases for \"\(movie.title)\".")
        )
    }

    var noMatchingReleases: some View {
        ContentUnavailableView(
            "No Releases Match",
            systemImage: "slash.circle",
            description: Text("No releases match the selected filters.")
        )
    }

    var searchingIndicator: some View {
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

            if !instance.releases.customFormats.isEmpty {
                customFormatPicker
            }

            Section {
                Toggle("Only Approved", systemImage: "checkmark.seal", isOn: $sort.approvedOnly)
                Toggle("Only FreeLeech", systemImage: "f.square", isOn: $sort.freeleechOnly)
            }
        }
    }

    var toolbarSortingButton: some View {
        Menu {
            Section {
                Picker("Sort By", selection: $sort.option) {
                    ForEach(MovieReleaseSort.Option.allCases) { option in
                        option.label
                    }
                }
                .pickerStyle(.inline)
                .onChange(of: sort.option) {
                    switch sort.option {
                    case .byWeight: sort.isAscending = false
                    case .byAge: sort.isAscending = true
                    case .byFilesize: sort.isAscending = true
                    case .bySeeders: sort.isAscending = false
                    case .byCustomScore: sort.isAscending = false
                    }
                }
            }

            Section {
                Picker("Direction", selection: $sort.isAscending) {
                    Label("Ascending", systemImage: "arrowtriangle.up").tag(true)
                    Label("Descending", systemImage: "arrowtriangle.down").tag(false)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .imageScale(.medium)
        }
    }

    var indexersPicker: some View {
        Menu {
            Picker("Indexer", selection: $sort.indexer) {
                Text("Any Indexer").tag(".all")

                ForEach(instance.releases.indexers, id: \.self) { indexer in
                    Text(indexer).tag(Optional.some(indexer))
                }
            }
            .pickerStyle(.inline)
        } label: {
            Label("Indexer", systemImage: "building.2")
        }
    }

    var qualityPicker: some View {
        Menu {
            Picker("Quality", selection: $sort.quality) {
                Text("Any Quality").tag(".all")

                ForEach(instance.releases.qualities, id: \.self) { quality in
                    Text(quality).tag(Optional.some(quality))
                }
            }
            .pickerStyle(.inline)
        } label: {
            Label("Quality", systemImage: "film.stack")
        }
    }

    var customFormatPicker: some View {
        Menu {
            Picker("Custom Format", selection: $sort.customFormat) {
                Text("Any Format").tag(".all")

                ForEach(instance.releases.customFormats, id: \.self) { format in
                    Text(format).tag(Optional.some(format))
                }
            }
            .pickerStyle(.inline)
        } label: {
            Label("Custom Format", systemImage: "person.badge.plus")
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
