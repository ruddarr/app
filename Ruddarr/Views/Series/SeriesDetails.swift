import SwiftUI
import TelemetryDeck

struct SeriesDetails: View {
    @Binding var series: Series

    @State private var dispatchingSearch: Bool = false
    @State private var descriptionTruncated = true

    @EnvironmentObject var settings: AppSettings
    @Environment(SonarrInstance.self) var instance

    @Environment(\.deviceType) var deviceType

    var body: some View {
        VStack(alignment: .leading) {
            header
                .padding(.bottom)

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
                if !series.seasons.isEmpty {
                    seasons
                }

                information
                    .padding(.bottom)
            }
        }
    }

    var hasDescription: Bool {
        !(series.overview ?? "").trimmed().isEmpty
    }

    var description: some View {
        HStack(alignment: .top) {
            Text(series.overview ?? "")
                .font(.callout)
                .transition(.slide)
                .lineLimit(descriptionTruncated ? 4 : nil)
                .textSelection(.enabled)
                .onTapGesture {
                    withAnimation(.snappy) { descriptionTruncated = false }
                }

            Spacer()
        }
        .onAppear {
            descriptionTruncated = deviceType == .phone
        }
    }

    var details: some View {
        Grid(alignment: .leading) {
            MediaDetailsRow(String(localized: "Status"), value: "\(series.status.label)")

            if !series.exists && series.seasonCount != 0 {
                MediaDetailsRow(String(localized: "Seasons"), value: series.seasonCount.formatted())
            }

            if let network = series.network, !network.isEmpty {
                MediaDetailsRow(String(localized: "Network"), value: network)
            }

            if !series.genres.isEmpty {
                MediaDetailsRow(String(localized: "Genre"), value: series.genreLabel)
            }

            if let episode = nextEpisode {
                MediaDetailsRow(
                    String(localized: "Airing", comment: "The time the next episode airs"),
                    value: episode.airDateTimeShortLabel
                )
            }
        }
    }

    @ViewBuilder
    var actions: some View {
        HStack(spacing: 24) {
            if series.exists {
                seriesActions
            } else {
                previewActions
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 450)
    }

    var seriesActions: some View {
        Group {
            Button {
                Task { await dispatchSearch() }
            } label: {
                ButtonLabel(
                    text: String(localized: "Search Monitored"),
                    icon: "magnifyingglass",
                    isLoading: dispatchingSearch
                )
                    .modifier(MediaPreviewActionModifier())
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
            .allowsHitTesting(!instance.series.isWorking)
            .onAppear(perform: triggerTipIfJustAdded)
            .popoverTip(NoAutomaticSearchTip())

            Spacer()
                .modifier(MediaPreviewActionSpacerModifier())
        }
    }

    var previewActions: some View {
        Group {
            Menu {
                SeriesLinks(series: series)
            } label: {
                ButtonLabel(text: String(localized: "Open In..."), icon: "arrow.up.right.square")
                    .modifier(MediaPreviewActionModifier())
            }
            .buttonStyle(.bordered)
            .tint(.secondary)

            Spacer()
                .modifier(MediaPreviewActionSpacerModifier())
        }
    }

    var qualityProfile: String {
        instance.qualityProfiles.first(
            where: { $0.id == series.qualityProfileId }
        )?.name ?? String(localized: "Unknown")
    }

    var seasons: some View {
        Section {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(series.seasons.reversed()) { season in
                    NavigationLink(value: SeriesPath.season(series.id, season.id)) {
                        SeasonCard(series: $series, season: season)
                    }.buttonStyle(.plain)
                }
            }
        } header: {
            Text("Seasons")
                .font(.title2.bold())
                .padding(.bottom, 6)
        }
    }

    var nextEpisode: Episode? {
        guard let nextAiring = series.nextAiring else { return nil }
        return instance.episodes.items.first { $0.airDateUtc == nextAiring }
    }

    func triggerTipIfJustAdded() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if series.added.timeIntervalSinceNow > -30 {
                Task {
                    await NoAutomaticSearchTip.mediaAdded.donate()
                }
            }
        }
    }

    func dispatchSearch() async {
        defer { dispatchingSearch = false }
        dispatchingSearch = true

        guard await instance.series.command(
            .seriesSearch(series.id)
        ) else {
            return
        }

        dependencies.toast.show(.monitoredSearchQueued)

        TelemetryDeck.signal("automaticSearchDispatched", parameters: ["type": "series"])
        maybeAskForReview()
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
