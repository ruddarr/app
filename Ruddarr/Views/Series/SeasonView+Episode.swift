import SwiftUI
import TelemetryClient

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
            }
            .padding(.trailing)

            Spacer()

            if episode.hasAired {
                Button {
                    Task { await dispatchEpisodeSearch(episode.id) }
                } label: {
                    Image(systemName: "magnifyingglass")
                }

                // NavigationLink(value: SeriesView.Path.releases(series.id), label: {
                //     Label("Interactive Search", systemImage: "person")
                // })

                Button {
                    // TODO: fix me
                } label: {
                    Image(systemName: "person").symbolVariant(.fill)
                }
            }
        }

        // TODO: clean up
        // monitor icon
        // EO3
        // title (finale)
        // Air Date
        // runtime of episode?
        // quality & file size (or status)
    }

    @MainActor
    func dispatchEpisodeSearch(_ episode: Episode.ID) async {
        guard await instance.series.command(.episodeSearch([episode])) else {
            return
        }

        dependencies.toast.show(.searchQueued)

        TelemetryManager.send("automaticSearchDispatched", with: ["type": "episode"])
    }
}
