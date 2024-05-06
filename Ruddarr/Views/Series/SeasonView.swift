import SwiftUI
import TelemetryClient

// http://10.0.1.5:8989/api/v3/release?seriesId=67&seasonNumber=2
// http://10.0.1.5:8989/api/v3/release?episodeId=15784

struct SeasonView: View {
    @Binding var series: Series
    var seasonNumber: Season.ID

    // TODO: needs work!
    // @State private var fetched: Bool = false

    @EnvironmentObject var settings: AppSettings
    @Environment(SonarrInstance.self) var instance

    var body: some View {
        ScrollView {
            Group {
                header
                    .padding(.bottom)

                actions
                    .padding(.bottom)

                Section {
                    if instance.episodes.isWorking {
                        ProgressView().tint(.secondary)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(episodes) { episode in
                                NavigationLink(value: SeriesView.Path.episode(episode.seriesId, episode)) {
                                    episodeRow(episode)
                                }
                                Divider()
                            }
                        }
                    }
                } header: {
                    Text(season.episodeCountLabel)
                        .font(.title2)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 6)
                }
            }
            .viewPadding(.horizontal)
        }
        .refreshable {
            await refresh()
        }
        .toolbar {
            toolbarMonitorButton
            // toolbarMenu
            // TODO: needs work
        }
        .task {
            // guard !fetched else { return }
            await instance.episodes.fetch(series)
            // fetched = true
        }
        .alert(
            isPresented: instance.episodes.errorBinding,
            error: instance.episodes.error
        ) { _ in
            Button("OK") { instance.episodes.error = nil }
        } message: { error in
            Text(error.recoverySuggestionFallback)
        }
        .overlay {
            // TODO: fix me
//            if instance.releases.isSearching {
//                searchingIndicator
//            } else if instance.releases.items.isEmpty && fetched {
//                noReleasesFound
//            } else if releases.isEmpty && fetched {
//                noMatchingReleases
//            }
        }
    }

    var season: Season {
        series.seasonById(seasonNumber)!
    }

    var episodes: [Episode] {
        instance.episodes.items.filter { $0.seasonNumber == seasonNumber }
    }

    var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(series.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 250, alignment: .leading)
                .offset(y: 2)

            Text("Season \(season.seasonNumber)")
                .font(.largeTitle.bold())

            HStack(spacing: 6) {
                Text(year)

                // TODO: runtime? certification?

                if let bytes = season.statistics?.sizeOnDisk, bytes > 0 {
                    Bullet()
                    Text(formatBytes(bytes))
                }
            }
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var year: String {
        let episode = episodes
            .filter { $0.airDateUtc != nil }
            .min(by: { $0.airDateUtc! < $1.airDateUtc! })

        if let date = episode?.airDateUtc {
            return String(Calendar.current.component(.year, from: date))
        }

        return String(localized: "TBA")
    }

    @ViewBuilder
    var actions: some View {
        HStack(spacing: 24) {
            Button {
                Task { await dispatchSeasonSearch() }
            } label: {
                ButtonLabel(text: "Automatic", icon: "magnifyingglass")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
            // TODO: fix me
            // .allowsHitTesting(!instance.movies.isWorking)

            NavigationLink(value: SeriesView.Path.series(series.id), label: {
                ButtonLabel(text: "Interactive", icon: "person.fill")
                    .frame(maxWidth: .infinity)
            })
            .buttonStyle(.bordered)
            .tint(.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 450)
    }

    @ToolbarContentBuilder
    var toolbarMonitorButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                Task { await toggleMonitor() }
            } label: {
                ToolbarMonitorButton(monitored: .constant(season.monitored))
            }
            .buttonStyle(.plain)
            .allowsHitTesting(!instance.series.isWorking)
            .disabled(!series.monitored)
            .id(UUID())
        }
    }
}

extension SeasonView {
    @MainActor
    func toggleMonitor() async {
        guard let index = series.seasons.firstIndex(where: { $0.id == seasonNumber }) else {
            return
        }

        series.seasons[index].monitored.toggle()

        guard await instance.series.push(series) else {
            return
        }

        dependencies.toast.show(season.monitored ? .monitored : .unmonitored)
    }

    @MainActor
    func refresh() async {
        guard await instance.series.command(.refresh(series.id)) else {
            return
        }

        dependencies.toast.show(.refreshQueued)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            Task { await instance.series.fetch() }
        }
    }

    @MainActor
    func dispatchSeasonSearch() async {
        guard await instance.series.command(.seasonSearch(series.id, season: seasonNumber)) else {
            return
        }

        dependencies.toast.show(.searchQueued)

        TelemetryManager.send("automaticSearchDispatched", with: ["type": "season"])
    }
}

#Preview {
    let series: [Series] = PreviewData.load(name: "series")
    let item = series.first(where: { $0.id == 67 }) ?? series[0] // 15

    dependencies.router.selectedTab = .series

    dependencies.router.seriesPath.append(
        SeriesView.Path.series(item.id)
    )

    dependencies.router.seriesPath.append(
        SeriesView.Path.season(item.id, 2)
    )

    return ContentView()
        .withSonarrInstance(series: series)
        .withAppState()
}
