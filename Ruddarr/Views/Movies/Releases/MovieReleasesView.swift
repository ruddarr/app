import SwiftUI

struct MovieReleasesView: View {
    @Binding var movie: Movie

    @State private var releases: [MovieRelease] = []
    @State private var fetched: Movie.ID?
    @State private var selectedRelease: MovieRelease?

    @AppStorage("movieReleaseSort", store: dependencies.store) private var sort: MovieReleaseSort = .init()

    @EnvironmentObject var settings: AppSettings
    @Environment(\.deviceType) private var deviceType
    @Environment(RadarrInstance.self) private var instance

    var body: some View {
        List {
            ForEach(releases) { release in
                Button {
                    selectedRelease = release
                } label: {
                    MovieReleaseRow(release: release, movie: movie)
                        .environment(instance)
                        .environmentObject(settings)
                }
                .buttonStyle(.plain)
            }

            if hasHiddenReleases {
                HiddenReleases()
            }
        }
        .listStyle(.inset)
        .searchable(text: $sort.search, placement: .drawerOrToolbar)
        .toolbar {
            toolbarButtons
        }
        .task {
            guard !hasFetched else { return }
            if settings.releaseFilters == .reset { sort = .init() }
            releases = []
            sort.search = ""
            await instance.releases.search(movie)
            updateDisplayedReleases()
            fetched = movie.id
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
        }.tint(nil)
        .overlay {
            if instance.releases.isSearching {
                SearchingIndicator()
            } else if instance.releases.items.isEmpty && hasFetched {
                noReleasesFound
            } else if releases.isEmpty && hasFetched {
                noMatchingReleases
            }
        }
        .sheet(item: $selectedRelease) { release in
            MovieReleaseSheet(release: release, movie: movie)
                .presentationDetents(dynamic: [deviceType == .phone ? .medium : .large])
                .presentationBackground(.systemBackground)
                .environment(instance)
                .environmentObject(settings)
        }
    }

    var hasFetched: Bool {
        fetched == movie.id
    }

    var hasHiddenReleases: Bool {
        sort.hasFilter &&
        !releases.isEmpty &&
        releases.count < instance.releases.items.count
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
            if sort.search.trimmed().isEmpty {
                Text("No releases match the selected filters.")
            } else if sort.hasFilter {
                Text("No releases match the selected filters and \"\(sort.search.trimmed())\".")
            } else {
                Text("No releases match \"\(sort.search.trimmed())\".")
            }
        } actions: {
            Button("Clear Filters") {
                sort.resetFilters()
            }.opacity(sort.hasFilter ? 1 : 0)
        }
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
        Task {
            try? await Task.sleep(for: .milliseconds(10))
            releases = sort.filterAndSortItems(instance.releases.items, movie)
        }
    }
}

extension MovieReleasesView {
    @ToolbarContentBuilder
    var toolbarButtons: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            toolbarSortingButton
        }

        ToolbarItem(placement: .primaryAction) {
            toolbarFilterButton
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
                Toggle(
                    String(localized: "Approved", comment: "Release filter"),
                    systemImage: "checkmark.seal",
                    isOn: $sort.approved
                )
                Toggle(
                    String(localized: "FreeLeech", comment: "Release filter"),
                    systemImage: "f.square",
                    isOn: $sort.freeleech
                )
                Toggle(
                    String(localized: "Original", comment: "Release filter (original language)"),
                    systemImage: "character.bubble",
                    isOn: $sort.originalLanguage
                )
            }
        } label: {
            if sort.hasFilter {
                Image("filters.badge")
                    .offset(y: 3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.tint, .primary)
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
                }.pickerStyle(.inline)
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .imageScale(.medium)
        }
        .tint(.primary)
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
            Label(
                sort.indexer == ".all" ? String(localized: "Indexer") : sort.indexer,
                systemImage: "building.2"
            )
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
            Label(
                sort.quality == ".all" ? String(localized: "Quality") : sort.quality,
                systemImage: "film.stack"
            )
        }
    }

    var protocolPicker: some View {
        Menu {
            Picker("Protocol", selection: $sort.network) {
                Text("Any Protocol").tag(".all")

                ForEach(instance.releases.protocols, id: \.self) { type in
                    Text(type).tag(Optional.some(type))
                }
            }
            .pickerStyle(.inline)
        } label: {
            Label(
                sort.network == ".all" ? String(localized: "Protocol") : sort.network,
                systemImage: "point.3.connected.trianglepath.dotted"
            )
        }
    }

    var languagePicker: some View {
        Menu {
            Picker("Language", selection: $sort.language) {
                Text("Any Language").tag(".all")
                Text("Multilingual").tag(".multi")

                ForEach(instance.releases.languages, id: \.self) { language in
                    Text(language).tag(Optional.some(language))
                }
            }
            .pickerStyle(.inline)
        } label: {
            let label = switch sort.language {
            case ".all": String(localized: "Language")
            case ".multi": String(localized: "Multilingual")
            default: sort.language
            }

            Label(label, systemImage: "waveform")
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
            Label(
                sort.customFormat == ".all" ? String(localized: "Custom Format") : sort.customFormat,
                systemImage: "person.badge.plus"
            )
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
