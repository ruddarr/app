import SwiftUI
import TelemetryClient

struct SeriesDetails: View {
    @Binding var series: Series

    @State private var descriptionTruncated = true

    @EnvironmentObject var settings: AppSettings
    @Environment(SonarrInstance.self) private var instance

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.deviceType) var deviceType

    var body: some View {
        VStack(alignment: .leading) {
            header
                .padding(.bottom)

            if series.exists {
                nextAiring
                    .padding(.bottom)
            }

            details
                .padding(.bottom)

            if hasDescription {
                description
                    .padding(.bottom)
            }

            if deviceType == .phone && !series.exists {
                actions
                    .padding(.bottom)
            }

            if series.exists {
                seasons
                    .padding(.bottom)

                information
                    .padding(.bottom)
            }
        }
    }

    var hasDescription: Bool {
        !(series.overview ?? "").trimmingCharacters(in: .whitespaces).isEmpty
    }

    var description: some View {
        HStack(alignment: .top) {
            Text(series.overview ?? "")
                .font(.callout)
                .transition(.slide)
                .lineLimit(descriptionTruncated ? 4 : nil)
                .textSelection(.enabled)
                .onTapGesture {
                    withAnimation(.spring(duration: 0.35)) { descriptionTruncated = false }
                }

            Spacer()
        }
        .onAppear {
            descriptionTruncated = deviceType == .phone
        }
    }

    var details: some View {
        Grid(alignment: .leading) {
            MediaDetailsRow("Status", value: "\(series.status.label)")

            if !series.exists && series.seasonCount != 0 {
                MediaDetailsRow("Seasons", value: series.seasonCount.formatted())
            }

            if let network = series.network, !network.isEmpty {
                MediaDetailsRow("Network", value: network)
            }

            if !series.genres.isEmpty {
                MediaDetailsRow("Genre", value: series.genreLabel)
            }
        }
    }

    @ViewBuilder
    var actions: some View {
        HStack(spacing: 24) {
            Menu {
                SeriesContextMenu(series: series)
            } label: {
                ButtonLabel(text: "Open In...", icon: "arrow.up.right.square")
                    .modifier(MediaPreviewActionModifier())
            }
            .buttonStyle(.bordered)
            .tint(.secondary)

            Spacer()
                .modifier(MediaPreviewActionSpacerModifier())
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 450)
    }

    var qualityProfile: String {
        instance.qualityProfiles.first(
            where: { $0.id == series.qualityProfileId }
        )?.name ?? String(localized: "Unknown")
    }

    var seasons: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(series.seasons.reversed()) { season in
                NavigationLink(
                    value: SeriesPath.season(series.id, season.id)
                ) {
                    GroupBox {
                        HStack(spacing: 12) {
                            Text(season.label)
                                .fontWeight(.medium)

                            if let progress = season.progressLabel {
                                Text(progress)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button {
                                Task { await monitorSeason(season.id) }
                            } label: {
                                Image(systemName: "bookmark")
                                    .symbolVariant(season.monitored ? .fill : .none)
                                    .foregroundStyle(colorScheme == .dark ? .lightGray : .darkGray)
                            }
                            .buttonStyle(.plain)
                            .overlay(Rectangle().padding(18))
                            .allowsHitTesting(!instance.series.isWorking)
                            .disabled(!series.monitored)
                        }
                    }
                }.buttonStyle(.plain)
            }
        }
    }

    var nextEpisode: Episode? {
        guard let nextAiring = series.nextAiring else { return nil }
        return instance.episodes.items.first { $0.airDateUtc == nextAiring }
    }

    @ViewBuilder
    var nextAiring: some View {
        if let episode = nextEpisode {
            NavigationLink(value: SeriesPath.season(series.id, episode.seasonNumber)) {
                GroupBox {
                    VStack(alignment: .leading) {
                        HStack(spacing: 4) {
                            Text(episode.episodeLabel)
                                .lineLimit(1)
                            Bullet()
                            Text(episode.titleLabel)
                                .lineLimit(1)
                        }
                        .fontWeight(.medium)

                        Text(episode.airDateUtc!.formatted(date: .complete, time: .shortened))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                        Text("Next Episode")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(settings.theme.tint)
                    .padding(.bottom, 2)
                }
            }
            .buttonStyle(.plain)
        }
    }

    @MainActor
    func monitorSeason(_ season: Season.ID) async {
        guard let index = series.seasons.firstIndex(where: { $0.id == season }) else {
            return
        }

        series.seasons[index].monitored.toggle()

        guard await instance.series.push(series) else {
            return
        }

        dependencies.toast.show(series.seasons[index].monitored ? .monitored : .unmonitored)
    }
}

struct SeriesDetailsPreview: View {
    let series: [Series]
    @State var item: Series

    init(_ file: String) {
        let series: [Series] = PreviewData.load(name: file)
        self.series = series
        self._item = State(initialValue: series.first(where: { $0.id == 67 }) ?? series[0])
    }

    var body: some View {
        SeriesDetailView(series: $item)
            .withSonarrInstance(series: series)
            .withAppState()
    }
}

#Preview("Preview") {
    SeriesDetailsPreview("series-lookup")
}

#Preview {
    SeriesDetailsPreview("series")
}
