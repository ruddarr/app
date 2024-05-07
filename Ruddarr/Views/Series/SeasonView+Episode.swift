import SwiftUI
import TelemetryClient

struct EpisodeRow: View {
    var episode: Episode

    @EnvironmentObject var settings: AppSettings
    @Environment(SonarrInstance.self) var instance

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack(spacing: 6) {
                    Text(verbatim: "\(episode.episodeNumber).")
                        .foregroundStyle(.secondary)

                    Text(episode.titleLabel)
                        .lineLimit(1)
                }

                details
            }.padding(.trailing)

            Spacer()

            actions
        }

        // TODO: clean up
        // monitor icon
        // EO3
        // title (finale)
        // Air Date
        // runtime of episode?
        // quality & file size (or status)
    }

    var details: some View {
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
                        // .foregroundStyle(settings.theme.tint) // TODO: fix me
                }
            }

        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    var actions: some View {
        Group {
            if episode.hasAired {
                Button {
                    Task { await dispatchSearch(episode.id) }
                } label: {
                    Image(systemName: "magnifyingglass")
                }

                // NavigationLink(value: SeriesPath.releases(series.id), label: {
                //     Label("Interactive Search", systemImage: "person")
                // })

                Button {
                    // TODO: fix me
                } label: {
                    Image(systemName: "person").symbolVariant(.fill)
                }
            }
        }
    }

    @MainActor
    func dispatchSearch(_ episode: Episode.ID) async {
        guard await instance.series.command(
            .episodeSearch([episode])
        ) else {
            return
        }

        dependencies.toast.show(.searchQueued)

        TelemetryManager.send("automaticSearchDispatched", with: ["type": "episode"])
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
