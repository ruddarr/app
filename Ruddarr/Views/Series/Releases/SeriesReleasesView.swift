import SwiftUI

struct SeriesReleasesView: View {
    @Binding var series: Series
    var seasonId: Season.ID?
    var episodeId: Episode.ID?

    @State private var releases: [SeriesRelease] = []
    @State private var fetched: (Series.ID?, Season.ID?, Episode.ID?) = (nil, nil, nil)
    @State private var selectedRelease: SeriesRelease?

    @AppStorage("seriesReleaseSort", store: dependencies.store) private var sort: SeriesReleaseSort = .init()

    @Environment(AppSettings.self) private var settings
    @Environment(SonarrInstance.self) private var instance
    @Environment(\.deviceType) private var deviceType

    var body: some View {
        List {
            ForEach(releases) { release in
                let runtime = release.runtime(seriesRuntime: series.runtime) {
                    instance.episodes.runtime(for: $0)
                }

                Button {
                    selectedRelease = release
                } label: {
                    SeriesReleaseRow(release: release, runtime: runtime)
                        .environment(instance)
                        .environment(settings)
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
            sort.seasonPack = seasonId == nil ? .episode : .season
            await instance.releases.search(series, seasonId, episodeId)
            releases = sort.filterAndSortItems(instance.releases.items, series)
            fetched = (series.id, seasonId, episodeId)
        }
        .onChange(of: sort.option, updateSortDirection)
        .onChange(of: sort, updateDisplayedReleases)
        .sensoryAlert(
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
            SeriesReleaseSheet(
                release: release,
                seriesId: series.id,
                seasonId: seasonId,
                episodeId: episodeId
            )
            .environment(instance)
            .environment(settings)
            .presentationDetents(dynamic: [deviceType == .phone ? .medium : .large])
            .presentationBackground(.sheetBackground)
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
            releases = sort.filterAndSortItems(instance.releases.items, series)
        }
    }
}

extension SeriesReleasesView {
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

            if !instance.releases.releaseGroups.isEmpty {
                releaseGroupPicker
            }

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
                Image("filters.badge")
                    .offset(y: 3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.tint, .primary)
            } else {
                Image(systemName: "line.3.horizontal.decrease")
            }
        }
        .menuIndicator(.hidden)
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

            Section {
                ControlGroup {
                    ForEach(ReleaseLayout.allCases) { value in
                        Toggle(isOn: layoutBinding(value)) {
                            Label(value.label, systemImage: value.icon)
                        }
                    }
                }
                .labelStyle(.titleAndIcon)
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .imageScale(.medium)
        }
        .tint(.primary)
        .menuIndicator(.hidden)
    }

    func layoutBinding(_ value: ReleaseLayout) -> Binding<Bool> {
        Binding(
            get: { settings.releases == value },
            set: { if $0 { settings.releases = value } }
        )
    }

    var indexersPicker: some View {
        Menu {
            Picker("Indexer", selection: $sort.indexer) {
                Text("Any Indexer").tag(String.all)

                ForEach(instance.releases.indexers, id: \.self) { indexer in
                    Text(indexer).tag(Optional.some(indexer))
                }
            }
            .pickerStyle(.inline)
        } label: {
            Label(
                sort.indexer == .all ? String(localized: "Indexer") : sort.indexer,
                systemImage: "building.2"
            )
        }
    }

    var releaseGroupPicker: some View {
        Menu {
            Picker("Release Group", selection: $sort.releaseGroup) {
                Text("Any Group").tag(String.all)

                ForEach(instance.releases.releaseGroups, id: \.self) { group in
                    Text(group).tag(Optional.some(group))
                }
            }
            .pickerStyle(.inline)
        } label: {
            Label(
                sort.releaseGroup == .all ? String(localized: "Release Group") : sort.releaseGroup,
                systemImage: "person.2"
            )
        }
    }

    var qualityPicker: some View {
        Menu {
            Picker("Quality", selection: $sort.quality) {
                Text("Any Quality").tag(String.all)

                ForEach(instance.releases.qualities, id: \.self) { quality in
                    Text(quality).tag(Optional.some(quality))
                }
            }
            .pickerStyle(.inline)
        } label: {
            Label(
                sort.quality == .all ? String(localized: "Quality") : sort.quality,
                systemImage: "film.stack"
            )
        }
    }

    var protocolPicker: some View {
        Menu {
            Picker("Protocol", selection: $sort.network) {
                Text("Any Protocol").tag(String.all)

                ForEach(instance.releases.protocols, id: \.self) { type in
                    Text(type).tag(Optional.some(type))
                }
            }
            .pickerStyle(.inline)
        } label: {
            Label(
                sort.network == .all ? String(localized: "Protocol") : sort.network,
                systemImage: "point.3.connected.trianglepath.dotted"
            )
        }
    }

    var languagePicker: some View {
        Menu {
            Picker("Language", selection: $sort.language) {
                Text("Any Language").tag(String.all)
                Text("Multilingual").tag(String.multi)

                ForEach(instance.releases.languages, id: \.self) { language in
                    Text(language).tag(Optional.some(language))
                }
            }
            .pickerStyle(.inline)
        } label: {
            let label = switch sort.language {
            case .all: String(localized: "Language")
            case .multi: String(localized: "Multilingual")
            default: sort.language
            }

            Label(label, systemImage: "waveform")
        }
    }

    var customFormatPicker: some View {
        Menu {
            Picker("Custom Format", selection: $sort.customFormat) {
                Text("Any Format").tag(String.all)

                ForEach(instance.releases.customFormats, id: \.self) { format in
                    Text(format).tag(Optional.some(format))
                }
            }
            .pickerStyle(.inline)
        } label: {
            Label(
                sort.customFormat == .all ? String(localized: "Custom Format") : sort.customFormat,
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
