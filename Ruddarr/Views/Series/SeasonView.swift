import SwiftUI
import TelemetryClient

struct SeasonView: View {
    @Binding var series: Series
    var seasonNumber: Season.ID

    // @State private var fetched: Bool = false
    @State private var showEpisode: Episode?

    @EnvironmentObject var settings: AppSettings
    @Environment(SonarrInstance.self) private var instance

    // TODO: refresh season (series) when pulling down...

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
                                episodeRow(episode)
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
            }.viewPadding(.horizontal)
        }
        .toolbar {
            toolbarMonitorButton
            // toolbarMenu
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
        .sheet(item: $showEpisode) { episode in
            EpisodeSheet(series: series, episode: episode)
        }
        .overlay {
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

    var year: Date {
        Date.now
        // Calendar.current.component(.year, from: episodes.min(by: { $0.airDateUtc < $1.airDateUtc }).airDateUtc)
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
                Text(year.formatted(.dateTime.year()))

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

    @ViewBuilder
    var actions: some View {
        HStack(spacing: 24) {
            Button {
                Task { @MainActor in
//                    guard await instance.series.command(.seasonSearch(series.id, season: )) else {
//                        return
//                    }

                    dependencies.toast.show(.searchQueued)

                    TelemetryManager.send("automaticSearchDispatched")
                }
            } label: {
                ButtonLabel(text: "Automatic", icon: "magnifyingglass")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
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
                Circle()
                    .fill(.secondarySystemBackground)
                    .frame(width: 28, height: 28)
                    .overlay {
                        Image(systemName: "bookmark")
                            .font(.system(size: 11, weight: .bold))
                            .symbolVariant(series.monitored ? .fill : .none)
                            .foregroundStyle(.tint)
                    }
            }
            .buttonStyle(.plain)
            .allowsHitTesting(!instance.series.isWorking)
            .id(UUID())
        }
    }
}

// http://10.0.1.5:8989/api/v3/release?seriesId=67&seasonNumber=2
// http://10.0.1.5:8989/api/v3/release?episodeId=15784

extension SeasonView {
    func episodeRow(_ episode: Episode) -> some View {
        HStack {
            VStack(alignment: .leading) {
                HStack(spacing: 6) {
                    Text(verbatim: "\(episode.episodeNumber).").foregroundStyle(.secondary)
                    Text(episode.titleLabel).lineLimit(1)
                }

                Group {
                    HStack(spacing: 6) {
                        Text(episode.statusLabel)

                        if let airdate = episode.airDateUtc {
                            Bullet()
                            Text(airdate.formatted(date: .abbreviated, time: .omitted))
                            // TODO: Today 5pm, tomorrow
                        }

                        if let finale = episode.finaleType {
                            Bullet()
                            Text(finale.label)
                                .foregroundStyle(settings.theme.tint)
                        }
                    }

                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }.padding(.trailing)

            Spacer()

            if episode.hasAired {
                Button {
                    // Task { await dispatchSearch() }
                } label: {
                    Image(systemName: "magnifyingglass")
                }

                Button {
                    // SeriesView.Path
                } label: {
                    Image(systemName: "person").symbolVariant(.fill)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showEpisode = episode
        }

        // monitor icon
        // EO3
        // title (finale)
        // Air Date
        // runtime of episode?
        // quality & file size (or status)
    }


    @MainActor
    func toggleMonitor() async {
        // season.monitored.toggle()

        //        guard await instance.series.update(series) else {
        //            return
        //        }

        dependencies.toast.show(series.monitored ? .monitored : .unmonitored)
    }

    @MainActor
    func dispatchSeasonSearch() async {
        guard await instance.series.command(.seriesSearch(series.id)) else {
            return
        }

        dependencies.toast.show(.searchQueued)

        TelemetryManager.send("automaticSearchDispatched")
    }

    @MainActor
    func dispatchEpisodeSearch() async {
        //        guard await instance.series.command(.episodeSearch(series.id, 111)) else {
        //            return
        //        }

        dependencies.toast.show(.searchQueued)

        TelemetryManager.send("automaticSearchDispatched")
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
