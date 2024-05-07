import SwiftUI
import TelemetryClient

// TODO: center single buttons like Music/Podcasts does.

struct EpisodeView: View {
    @Binding var series: Series
    var episodeId: Episode.ID

    @State private var descriptionTruncated = true

    @EnvironmentObject var settings: AppSettings
    @Environment(SonarrInstance.self) var instance

    @Environment(\.dismiss) private var dismiss

    let smallScreen = UIDevice.current.userInterfaceIdiom == .phone

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                header
                    .padding(.bottom)

                actions
                    .padding(.bottom)

                // TODO: fix these...
                // TODO: size on disk
                // file details (media etc.)
                // monitor button
                // search buttons
                // history
            }
            .padding(.top)
            .viewPadding(.horizontal)
        }
        .toolbar {
            toolbarMonitorButton
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

    var episode: Episode {
        instance.episodes.items.first(where: { $0.id == episodeId }) ?? Episode.void
    }

    var header: some View {
        VStack(alignment: .leading) {
            Text(episode.statusLabel)
            .font(.footnote)
            .fontWeight(.semibold)
            .tracking(1.1)
            .foregroundStyle(settings.theme.tint)

            Text(episode.titleLabel)
                .font(.largeTitle.bold())
                .kerning(-0.5)

            HStack(spacing: 6) {
                Text(episode.episodeLabel)
                Bullet()
                Text(episode.airDateLabel)

                if let runtime = episode.runtimeLabel {
                    Bullet()
                    Text(runtime)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if episode.overview != nil {
                description
                    .padding(.top, 6)
            }
        }
    }

    var description: some View {
        HStack(alignment: .top) {
            Text(episode.overview ?? "")
                .font(.callout)
                .transition(.slide)
                .lineLimit(descriptionTruncated ? 3 : nil)
                .textSelection(.enabled)
                .onTapGesture {
                    withAnimation(.spring(duration: 0.35)) { descriptionTruncated = false }
                }

            Spacer()
        }
        .onAppear {
            descriptionTruncated = smallScreen
        }
    }

    @ToolbarContentBuilder
    var toolbarMonitorButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                Task { await toggleMonitor() }
            } label: {
                ToolbarMonitorButton(monitored: .constant(episode.monitored))
            }
            .buttonStyle(.plain)
            .allowsHitTesting(!instance.episodes.isWorking)
            .disabled(!series.monitored)
            .id(UUID())
        }
    }

    @ViewBuilder
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
                value: SeriesPath.releases(series.id, nil, episodeId)
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
}

extension EpisodeView {
    @MainActor
    func toggleMonitor() async {
        guard let index = instance.episodes.items.firstIndex(where: { $0.id == episode.id }) else {
            return
        }

        instance.episodes.items[index].monitored.toggle()

        guard await instance.episodes.monitor([episode.id], episode.monitored) else {
            return
        }

        dependencies.toast.show(episode.monitored ? .monitored : .unmonitored)
    }

    @MainActor
    func dispatchSearch() async {
        guard await instance.series.command(
            .episodeSearch([episode.id])) else {
            return
        }

        dependencies.toast.show(.searchQueued)

        TelemetryManager.send("automaticSearchDispatched", with: ["type": "episode"])
    }
}

#Preview {
    let series: [Series] = PreviewData.load(name: "series")
    let episodes: [Episode] = PreviewData.load(name: "series-episodes")
    let item = series.first(where: { $0.id == 15 }) ?? series[0]

    dependencies.router.selectedTab = .series

    dependencies.router.seriesPath.append(
        SeriesPath.series(item.id)
    )

    dependencies.router.seriesPath.append(
        SeriesPath.season(item.id, 2)
    )

    dependencies.router.seriesPath.append(
        SeriesPath.episode(item.id, episodes[24].id)
    )

    return ContentView()
        .withSonarrInstance(series: series, episodes: episodes)
        .withAppState()
}
