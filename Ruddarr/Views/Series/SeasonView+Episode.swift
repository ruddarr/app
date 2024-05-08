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

                HStack(spacing: 6) {
                    Text(episode.statusLabel)
                    Bullet()
                    Text(episode.airingToday ? episode.airDateTimeLabel : episode.airDateLabel)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                if let finale = episode.finaleType {
                    Text(finale.label)
                        .font(.subheadline)
                        .foregroundStyle(settings.theme.tint)
                }
            }.padding(.trailing)

            Spacer()

            actions
        }
        .contentShape(Rectangle())

        // TODO: monitor icon
        // TODO: quality & file size (instead of status?)
    }

    var actions: some View {
        Group {
            if episode.hasAired {
                Button {
                    Task { await dispatchSearch(episode.id) }
                } label: {
                    Image(systemName: "magnifyingglass")
                }

                NavigationLink(
                    value: SeriesPath.releases(episode.seriesId, nil, episode.id)
                ) {
                    Image(systemName: "person").symbolVariant(.fill)
                }
            }
        }.foregroundStyle(.primary)
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
