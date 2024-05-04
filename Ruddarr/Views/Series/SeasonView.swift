import SwiftUI
import TelemetryClient

struct SeasonView: View {
    @Binding var series: Series
    var seasonNumber: Season.ID

    @State private var fetched: Bool = false

    @EnvironmentObject var settings: AppSettings
    @Environment(SonarrInstance.self) private var instance

    // TODO: show size of season on disk...
    // TODO: refresh season (series) when pulling down...

    var body: some View {
        ScrollView {


            actions
                .viewPadding(.horizontal)
                .padding(.bottom)


            VStack(spacing: 12) {
                ForEach(episodes) { episode in
                    HStack {
                        VStack(alignment: .leading) {
                            HStack {
                                Text(episode.episodeLabel)
                                Bullet()
                                Text(episode.title ?? "TBA").lineLimit(1)
                            }
                            //

                            Group {
                                if !episode.hasAired {
                                    HStack {
                                        Text("Unaired")
                                        Bullet()
                                        // TODO: show time as well?
                                        Text(episode.airDateUtc?.formatted(date: .abbreviated, time: .omitted) ?? "xxx")
                                    }

                                } else if !episode.hasFile {
                                    Text("Missing")
                                } else {
                                    Text("Downloaded")
                                }
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        }.padding(.trailing)

                        Spacer()

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

                    // monitor icon
                    // EO3
                    // title (finale)
                    // Air Date
                    //
                    // quality & file size (or status)
                }
            }
            .viewPadding(.horizontal)
        }
        .navigationTitle("Season \(season.seasonNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(.inset)
        .task {
            guard !fetched else { return }
            await instance.episodes.fetch(series)
            fetched = true
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

    @ViewBuilder
    var actions: some View {
        HStack(spacing: 24) {
            Button {
                Task { @MainActor in
//                    guard await instance.movies.command(movie, command: .automaticSearch) else {
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
            //.allowsHitTesting(!instance.movies.isWorking)

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
}

#Preview {
    let series: [Series] = PreviewData.load(name: "series")
    let item = series.first(where: { $0.id == 67 }) ?? series[0] // 15

    dependencies.router.selectedTab = .series

    dependencies.router.seriesPath.append(
        SeriesView.Path.series(item.id)
    )

    dependencies.router.seriesPath.append(
        SeriesView.Path.season(item.id, 1)
    )

    return ContentView()
        .withSonarrInstance(series: series)
        .withAppState()
}
