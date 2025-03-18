import SwiftUI

struct SeriesReleasesView: View {
    @Binding var series: Series
    var seasonId: Season.ID?
    var episodeId: Episode.ID?

    @State private var releases: [SeriesRelease] = []
    @State private var fetched: (Series.ID?, Season.ID?, Episode.ID?) = (nil, nil, nil)

    @AppStorage("seriesReleaseSort", store: dependencies.store) private var sort: SeriesReleaseSort = .init()

    @EnvironmentObject var settings: AppSettings
    @Environment(SonarrInstance.self) private var instance

    var body: some View {
        List {
            ForEach(releases) { release in
                SeriesReleaseRow(
                    release: release,
                    seriesId: series.id,
                    seasonId: seasonId,
                    episodeId: episodeId
                )
                    .environment(instance)
                    .environmentObject(settings)
            }

            if hasHiddenReleases {
                HiddenReleases()
            }
        }
        .listStyle(.inset)
        .toolbar {
            toolbarButtons
        }
        .task {
            guard !hasFetched else { return }
            if settings.releaseFilters == .reset { sort = .init() }
            releases = []
            sort.seasonPack = seasonId == nil ? .episode : .season
            await instance.releases.search(series, seasonId, episodeId)
            updateDisplayedReleases()
            fetched = (series.id, seasonId, episodeId)
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
                SearchingIndicator()
            } else if instance.releases.items.isEmpty && hasFetched {
                noReleasesFound
            } else if releases.isEmpty && hasFetched {
                noMatchingReleases
            }
        }
    }

    var hasFetched: Bool {
        fetched == (series.id, seasonId, episodeId)
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
            description: Text("No releases found for \"\(series.title)\".")
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

    func updateSortDirection() {
        switch sort.option {
        case .bySeeders, .byQuality, .byCustomScore:
            sort.isAscending = false
        default:
            sort.isAscending = true
        }
    }

    // swiftlint:disable cyclomatic_complexity
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

        if sort.language == ".multi" {
            releases = releases.filter {
                ($0.languages?.count ?? 0) > 1 || $0.title.lowercased().contains("multi")
            }
        } else if sort.language != ".all" {
            releases = releases.filter { $0.languages?.contains { $0.label == sort.language } ?? false }
        }

        if sort.customFormat != ".all" {
            releases = releases.filter { $0.customFormats?.contains { $0.name == sort.customFormat } ?? false }
        }

        if sort.seasonPack == .season {
            releases = releases.filter { $0.fullSeason }
        }

        if sort.seasonPack == .episode {
            releases = releases.filter { !$0.fullSeason }
        }

        if sort.approved {
            releases = releases.filter { !$0.rejected }
        }

        if sort.freeleech {
            releases = releases.filter { $0.releaseFlags.contains(.freeleech) }
        }

        if sort.originalLanguage {
            releases = releases.filter {
                $0.languages?.contains { $0.id == series.originalLanguage?.id } ?? false
            }
        }

        if sort.isAscending {
            releases = releases.reversed()
        }
    }
    // swiftlint:enable cyclomatic_complexity
}

extension SeriesReleasesView {
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
                seasonPackPicker
            }

            Section {
                Toggle("Approved", systemImage: "checkmark.seal", isOn: $sort.approved)
                Toggle("FreeLeech", systemImage: "f.square", isOn: $sort.freeleech)
                Toggle("Original", systemImage: "character.bubble", isOn: $sort.originalLanguage)
            }
        } label: {
            if sort.hasFilter {
                Image("filters.badge").offset(y: 3.2)
            } else {
                Image(systemName: "line.3.horizontal.decrease")
            }
        }
    }

    var toolbarSortingButton: some View {
        Menu {
            Section {
                Picker("Sort By", selection: $sort.option) {
                    ForEach(SeriesReleaseSort.Option.allCases) { option in
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
                sort.indexer == ".all" ? "Indexer" : sort.indexer,
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
                sort.quality == ".all" ? "Quality" : sort.quality,
                systemImage: "film.stack"
            )
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
            Label(
                sort.type == ".all" ? "Protocol" : sort.type,
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
            case ".all": "Language"
            case ".multi": "Multilingual"
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
                sort.customFormat == ".all" ? "Custom Format" : sort.customFormat,
                systemImage: "person.badge.plus"
            )
        }
    }

    var seasonPackPicker: some View {
        Picker("Season Pack", selection: $sort.seasonPack) {
            ForEach(SeriesReleaseSort.SeasonPack.allCases) { item in
                Label(item.label, systemImage: item.icon).tag(Optional.some(item))
            }
        }
        .pickerStyle(.inline)
    }
}

#Preview {
    let series: [Series] = PreviewData.load(name: "series")
    let item = series.first(where: { $0.id == 67 }) ?? series[0]

    dependencies.router.selectedTab = .series

    dependencies.router.seriesPath.append(
        SeriesPath.series(item.id)
    )

    dependencies.router.seriesPath.append(
        SeriesPath.releases(item.id, nil, 4)
    )

    return ContentView()
        .withSonarrInstance(series: series)
        .withAppState()
}
