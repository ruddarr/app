import SwiftUI
import TelemetryDeck

struct EpisodeView: View {
    @Binding var series: Series
    var episodeId: Episode.ID

    @State private var fileSheet: MediaFile?
    @State private var eventSheet: MediaHistoryEvent?
    @State private var descriptionTruncated = true
    @State private var showDeleteConfirmation = false

    @EnvironmentObject var settings: AppSettings
    @Environment(SonarrInstance.self) var instance

    @Environment(\.dismiss) private var dismiss
    @Environment(\.deviceType) private var deviceType

    var startOfToday = Calendar.current.startOfDay(for: Date())

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                header
                    .padding(.bottom)

                details
                    .padding(.bottom)

                if episode.overview != nil {
                    description
                        .padding(.bottom)
                }

                actions
                    .padding(.bottom)

                file

                history
            }
            .padding(.vertical)
            .viewPadding(.horizontal)
        }
        .navigationTitle(
            series.title.count < 20 ? series.title : "\(series.title.prefix(18))..."
        )
        .safeNavigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarMonitorButton
            toolbarMenu
        }
        .task {
            await instance.episodes.fetchHistory(episode)
        }
        .refreshable {
            await Task { await reload() }.value
        }
    }

    var episode: Episode {
        instance.episodes.items.first(where: { $0.id == episodeId }) ?? Episode.void
    }

    var episodeFile: MediaFile? {
        instance.files.items.first(where: { $0.id == episode.episodeFileId })
    }

    var header: some View {
        VStack(alignment: .leading) {
            Text(episode.statusLabel)
                .font(.caption)
                .fontWeight(.semibold)
                .textCase(.uppercase)
                .foregroundStyle(settings.theme.tint)

            Text(episode.titleLabel)
                .font(.largeTitle.bold())
                .kerning(-0.5)

            HStack(spacing: 6) {
                Text(episode.episodeLabel)

                if let runtime = episode.runtimeLabel {
                    Bullet()
                    Text(runtime)
                }

                Bullet()
                Text(
                    episode.airDateUtc ?? Date() > startOfToday
                        ? episode.airDateTimeLabel
                        : episode.airDateLabel
                )
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
    }

    var details: some View {
        Grid(alignment: .leading) {
            if let network = series.network, !network.isEmpty {
                MediaDetailsRow("Network", value: network)
            }

            if !series.genres.isEmpty {
                MediaDetailsRow("Genre", value: series.genreLabel)
            }

            if episode.isDownloaded {
                Group {
                    MediaDetailsRow("Video", value: mediaDetailsVideoQuality(episodeFile))
                    MediaDetailsRow("Audio", value: mediaDetailsAudioQuality(episodeFile))

                    if let subtitles = mediaDetailsSubtitles(episodeFile) {
                        MediaDetailsRow("Subtitles", value: subtitles)
                    }
                }.onTapGesture {
                    fileSheet = episodeFile
                }
            }
        }
    }

    var description: some View {
        HStack(alignment: .top) {
            Text(episode.overview ?? "")
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

    @ToolbarContentBuilder
    var toolbarMonitorButton: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Button {
                Task { await toggleMonitor() }
            } label: {
                ToolbarMonitorButton(monitored: .constant(episode.monitored))
            }
            .allowsHitTesting(instance.episodes.isMonitoring == 0)
            .disabled(!series.monitored)
            #if os(iOS)
                .buttonStyle(.plain)
            #endif
        }
    }

    @ToolbarContentBuilder
    var toolbarMenu: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Section {
                    EpisodeContextMenu(episode: episode)
                }

                if episodeFile != nil {
                    Section {
                        deleteFileButton
                    }
                }
            } label: {
                ToolbarActionButton()
            }
        }
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

    @ViewBuilder
    var file: some View {
        if let file = episodeFile {
            Section {
                EpisodeFileView(file: file)
                    .onTapGesture { fileSheet = file }
                    .contextMenu { deleteFileButton }
                    .popoverTip(DeleteFileTip())
                    .padding(.bottom)
            } header: {
                Text("File").font(.title2.bold()).padding(.bottom, 6)
            }
            .sheet(item: $fileSheet) { file in
                MediaFileSheet(file: file, runtime: episode.runtime ?? series.runtime)
                    .presentationDetents([.fraction(0.9)])
            }
            .alert(
                "Are you sure?",
                isPresented: $showDeleteConfirmation
            ) {
                Button("Delete File", role: .destructive) {
                    Task { await deleteEpisode() }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently erase the episode file.")
            }
        }
    }

    var deleteFileButton: some View {
        Button("Delete File", systemImage: "trash", role: .destructive) {
            showDeleteConfirmation = true
        }
    }

    @ViewBuilder
    var history: some View {
        if !instance.episodes.history.isEmpty {
            Section {
                ForEach(instance.episodes.history) { event in
                    MediaHistoryItem(event: event)
                        .padding(.bottom, 4)
                        .onTapGesture { eventSheet = event }
                }
            } header: {
                Text("History").font(.title2.bold()).padding(.bottom, 6)
            }
            .sheet(item: $eventSheet) { event in
                MediaEventSheet(event: event)
                    .presentationDetents(
                        event.eventType == .grabbed ? [.medium] : [.fraction(0.25)]
                    )
            }
        }
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
    func reload() async {
        await instance.episodes.fetch(series)
        await instance.files.fetch(series)
    }

    @MainActor
    func dispatchSearch() async {
        guard await instance.series.command(
            .episodeSearch([episode.id])) else {
            return
        }

        dependencies.toast.show(.episodeSearchQueued)

        TelemetryDeck.signal("automaticSearchDispatched", parameters: ["type": "episode"])
        maybeAskForReview()
    }

    @MainActor
    func deleteEpisode() async {
        if await instance.files.delete(episodeFile!) {
            dependencies.toast.show(.fileDeleted)
            await reload()
        }
    }
}

struct EpisodeFileView: View {
    var file: MediaFile

    var body: some View {
        GroupBox {
            HStack(spacing: 6) {
                Text(file.quality.quality.label)
                Bullet()
                Text(file.languageLabel)
                Bullet()
                Text(file.sizeLabel)
                Spacer()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        } label: {
            Text(file.filenameLabel)
        }
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
