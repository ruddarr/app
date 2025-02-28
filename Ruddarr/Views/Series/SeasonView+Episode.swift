import SwiftUI

struct EpisodeRow: View {
    var episode: Episode

    @EnvironmentObject var settings: AppSettings
    @Environment(SonarrInstance.self) var instance
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack(spacing: 6) {
                    Text("\(episode.episodeNumber.formatted()).", comment: "Prefix for episode title (episode number)")
                        .foregroundStyle(.secondary)

                    Text(episode.titleLabel)
                        .lineLimit(1)

                    if let finale = episode.finaleType {
                        Text(finale.label)
                            .font(.caption)
                            .foregroundStyle(settings.theme.tint)
                    }
                }

                HStack(spacing: 6) {
                    if let file = episodeFile {
                        Text(file.quality.quality.normalizedName)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(episode.statusLabel)
                            .foregroundStyle(episodeIsMissing ? .red : .secondary)
                    }

                    Bullet()

                    if episode.airingToday {
                        Text(episode.airDateTimeLabel)
                            .foregroundStyle(settings.theme.tint)
                    } else {
                        Text(episode.airDateLabel)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }.padding(.trailing)

            Spacer()

            monitorButton
        }
        .contentShape(Rectangle())
    }

    var series: Series {
        instance.series.byId(episode.seriesId) ?? Series.void
    }

    var season: Season? {
        series.seasonById(episode.seasonNumber)
    }

    var episodeFile: MediaFile? {
        instance.files.items.first(where: { $0.id == episode.episodeFileId })
    }

    var episodeIsMissing: Bool {
        episode.isMissing && series.monitored && season?.monitored == true
    }

    var monitorButton: some View {
        Button {
            Task { await toggleMonitor() }
        } label: {
            if instance.episodes.isMonitoring == episode.id {
                ProgressView().tint(.secondary)
            } else {
                Image(systemName: "bookmark")
                    .symbolVariant(episode.monitored ? .fill : .none)
                    .foregroundStyle(colorScheme == .dark ? .lightGray : .darkGray)
            }
        }
        .buttonStyle(.plain)
        .overlay(Rectangle().padding(18))
        .allowsHitTesting(instance.episodes.isMonitoring == 0)
        .disabled(!series.monitored)
    }

    func toggleMonitor() async {
        guard let index = instance.episodes.items.firstIndex(where: { $0.id == episode.id }) else {
            return
        }

        instance.episodes.items[index].monitored.toggle()

        guard await instance.episodes.monitor([episode.id], !episode.monitored) else {
            return
        }

        dependencies.toast.show(!episode.monitored ? .monitored : .unmonitored)
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
