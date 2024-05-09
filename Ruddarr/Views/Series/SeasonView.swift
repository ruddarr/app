import SwiftUI
import TelemetryClient

struct SeasonView: View {
    @Binding var series: Series
    var seasonId: Season.ID

    @EnvironmentObject var settings: AppSettings
    @Environment(SonarrInstance.self) var instance

    var body: some View {
        ScrollView {
            Group {
                header
                    .padding(.bottom)

                actions
                    .padding(.bottom)

                episodesList
            }
            .viewPadding(.horizontal)
        }
        .refreshable {
            await refresh()
        }
        .toolbar {
            toolbarMonitorButton
        }
        .task {
            guard !instance.episodes.fetched(series) else { return }
            await instance.episodes.fetch(series)
        }
        .alert(
            isPresented: instance.episodes.errorBinding,
            error: instance.episodes.error
        ) { _ in
            Button("OK") { instance.episodes.error = nil }
        } message: { error in
            Text(error.recoverySuggestionFallback)
        }
    }

    var season: Season {
        series.seasonById(seasonId)!
    }

    var episodes: [Episode] {
        instance.episodes.items.filter { $0.seasonNumber == seasonId }
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

                if let minutes = runtime {
                    Bullet()
                    Text(formatRuntime(minutes))
                }

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

    var runtime: Int? {
        let items = episodes.filter { $0.runtime > 0 }.map { $0.runtime }
        guard !items.isEmpty else { return nil }
        return items.sorted(by: <)[items.count / 2]
    }

    var actions: some View {
        HStack(spacing: 24) {
            Button {
                Task { await dispatchSearch() }
            } label: {
                ButtonLabel(text: "Automatic", icon: "magnifyingglass")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
            .allowsHitTesting(!instance.series.isWorking)

            NavigationLink(
                value: SeriesPath.releases(series.id, seasonId, nil)
            ) {
                ButtonLabel(text: "Interactive", icon: "person.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 450)
    }

    var episodesList: some View {
        Section {
            if instance.episodes.isFetching {
                ProgressView().tint(.secondary)
            } else {
                VStack(spacing: 12) {
                    ForEach(episodes) { episode in
                        NavigationLink(
                            value: SeriesPath.episode(episode.seriesId, episode.id)
                        ) {
                            EpisodeRow(episode: episode)
                                .environment(instance)
                                .environmentObject(settings)
                        }
                        .buttonStyle(.plain)

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
        guard let index = series.seasons.firstIndex(where: { $0.id == season.id }) else {
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
        guard await instance.series.command(
            .refresh(series.id)
        ) else {
            return
        }

        dependencies.toast.show(.refreshQueued)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            Task { await instance.series.fetch() }
        }
    }

    @MainActor
    func dispatchSearch() async {
        guard await instance.series.command(
            .seasonSearch(series.id, season: season.id)
        ) else {
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
        SeriesPath.series(item.id)
    )

    dependencies.router.seriesPath.append(
        SeriesPath.season(item.id, 2)
    )

    return ContentView()
        .withSonarrInstance(series: series)
        .withAppState()
}
