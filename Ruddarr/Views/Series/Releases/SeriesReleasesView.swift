import SwiftUI

struct SeriesReleasesView: View {
    @Binding var series: Series
    var seasonId: Season.ID?
    var episodeId: Episode.ID?

    @State private var releases: [SeriesRelease] = []
    @State private var sort: SeriesReleaseSort = .init()

    @State private var fetched: Bool = false
    @State private var waitingTextOpacity: Double = 0

    @EnvironmentObject var settings: AppSettings
    @Environment(SonarrInstance.self) private var instance

    var body: some View {
        List {
            ForEach(releases) { release in
                SeriesReleaseRow(release: release)
                    .environment(instance)
                    .environmentObject(settings)
            }
        }
        .listStyle(.inset)
        .toolbar {
            toolbarButtons
        }
        .task {
            releases = []
            sort.seasonPack = seasonId == nil ? .episode : .season
            await instance.releases.search(series, seasonId, episodeId)
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

        if sort.language != ".all" {
            releases = releases.filter { $0.languages.contains { $0.label == sort.language } }
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
            releases = releases.filter {
                $0.cleanIndexerFlags.contains(where: { $0.localizedStandardContains("freeleech") })
            }
        }

        if sort.originalLanguage {
            releases = releases.filter {
                $0.languages.contains(where: { $0.id == series.originalLanguage?.id })
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

            seasonPackPicker

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

    var seasonPackPicker: some View {
        Menu {
            Picker("Season Pack", selection: $sort.seasonPack) {
                ForEach(SeriesReleaseSort.SeasonPack.allCases) { item in
                    Text(item.label).tag(Optional.some(item))
                }
            }
            .pickerStyle(.inline)
        } label: {
            Label("Season Pack", systemImage: "shippingbox")
        }
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
