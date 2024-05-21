import SwiftUI

struct MovieReleasesView: View {
    @Binding var movie: Movie

    @State private var releases: [MovieRelease] = []
    @State private var sort: MovieReleaseSort = .init()

    @State private var fetched: Bool = false
    @State private var waitingTextOpacity: Double = 0

    @EnvironmentObject var settings: AppSettings
    @Environment(RadarrInstance.self) private var instance

    var body: some View {
        List {
            ForEach(releases) { release in
                MovieReleaseRow(release: release)
                    .environment(instance)
                    .environmentObject(settings)
            }
        }
        .listStyle(.inset)
        .toolbar {
            toolbarButtons
        }
        .task {
            guard !fetched else { return }
            await instance.releases.search(movie)

            updateDisplayedReleases()
            fetched = true
        }
        .onChange(of: sort.option, updateSortDirection)
        .onChange(of: sort, updateDisplayedReleases)
        .alert(
            isPresented: instance.releases.errorBinding,
            error: instance.releases.error
        ) { _ in
            Button("OK") { instance.releases.error = nil }
        } message: { error in
            Text(error.recoverySuggestionFallback)
        }
        .overlay {
            if instance.releases.isSearching {
                searchingIndicator
            } else if instance.releases.items.isEmpty && fetched {
                noReleasesFound
            } else if releases.isEmpty && fetched {
                noMatchingReleases
            }
        }
    }

    var noReleasesFound: some View {
        ContentUnavailableView(
            "No Releases Found",
            systemImage: "slash.circle",
            description: Text("No releases found for \"\(movie.title)\".")
        )
    }

    var noMatchingReleases: some View {
        ContentUnavailableView {
            Label("No Releases Match", systemImage: "slash.circle")
        } description: {
            Text("No releases match the selected filters.")
        } actions: {
            Button("Clear Filters") {
                sort.resetFilters()
            }
        }
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
                            withAnimation(.spring) { waitingTextOpacity = 1 }
                        }
                    }
            }
        }.tint(.secondary)
    }

    func updateSortDirection() {
        switch sort.option {
        case .bySeeders, .byQuality, .byCustomScore:
            sort.isAscending = false
        default:
            sort.isAscending = true
        }
    }

    func updateDisplayedReleases() {
        releases = instance.releases.items.sorted(by: sort.option.isOrderedBefore)

        if sort.type != ".all" {
            releases = releases.filter { $0.type.label == sort.type }
        }

        if sort.indexer != ".all" {
            releases = releases.filter { $0.indexerLabel == sort.indexer }
        }

        if sort.quality != ".all" {
            releases = releases.filter { $0.quality.quality.normalizedName == sort.quality }
        }

        if sort.language != ".all" {
            releases = releases.filter { $0.languages.contains { $0.label == sort.language } }
        }

        if sort.customFormat != ".all" {
            releases = releases.filter { $0.customFormats?.contains { $0.name == sort.customFormat } ?? false }
        }

        if sort.approved {
            releases = releases.filter { !$0.rejected }
        }

        if sort.freeleech {
            releases = releases.filter {
                $0.cleanIndexerFlags.contains(where: { $0.localizedStandardContains("freeleech") })
            }
        }

        if sort.originalLanguage {
            releases = releases.filter {
                $0.languages.contains(where: { $0.id == movie.originalLanguage.id })
            }
        }

        if sort.isAscending {
            releases = releases.reversed()
        }
    }
}

extension MovieReleasesView {
    @ToolbarContentBuilder
    var toolbarButtons: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            HStack {
                toolbarSortingButton
                toolbarFilterButton
            }.id(UUID())
        }
    }

    var toolbarFilterButton: some View {
        Menu {
            if instance.releases.protocols.count > 1 {
                protocolPicker
            }

            indexersPicker

            qualityPicker

            if !instance.releases.languages.isEmpty {
                languagePicker
            }

            if !instance.releases.customFormats.isEmpty {
                customFormatPicker
            }

            Section {
                Toggle("Approved", systemImage: "checkmark.seal", isOn: $sort.approved)
                Toggle("FreeLeech", systemImage: "f.square", isOn: $sort.freeleech)
                Toggle("Original", systemImage: "character.bubble", isOn: $sort.originalLanguage)
            }
        } label: {
            if sort.hasFilter {
                Image("filters.badge").offset(y: 3.2)
            } else{
                Image(systemName: "line.3.horizontal.decrease")
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

    var protocolPicker: some View {
        Menu {
            Picker("Protocol", selection: $sort.type) {
                Text("Any Protocol").tag(".all")

                ForEach(instance.releases.protocols, id: \.self) { type in
                    Text(type).tag(Optional.some(type))
                }
            }
            .pickerStyle(.inline)
        } label: {
            Label("Protocol", systemImage: "point.3.connected.trianglepath.dotted")
        }
    }

    var languagePicker: some View {
        Menu {
            Picker("Language", selection: $sort.language) {
                Text("Any Language").tag(".all")

                ForEach(instance.releases.languages, id: \.self) { language in
                    Text(language).tag(Optional.some(language))
                }
            }
            .pickerStyle(.inline)
        } label: {
            Label("Language", systemImage: "waveform")
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
    dependencies.router.moviesPath.append(MoviesPath.movie(movie.id))
    dependencies.router.moviesPath.append(MoviesPath.releases(movie.id))

    return ContentView()
        .withRadarrInstance(movies: movies)
        .withAppState()
}
