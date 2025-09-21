import SwiftUI
import TelemetryDeck

struct EpisodeView: View {
    @Binding var series: Series
    var episodeId: Episode.ID

    @State private var episode: Episode = Episode.void
    @State private var episodeFile: MediaFile?

    @State private var fileSheet: MediaFile?
    @State private var eventSheet: MediaHistoryEvent?

    @State private var dispatchingSearch: Bool = false
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

                if episodeFile != nil {
                    file
                }

                if !instance.episodes.history.isEmpty {
                    history
                }
            }
            .onAppear(perform: setEpisodeState)
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
        .refreshable {
            await Task { await reload() }.value
        }
        .task {
            await instance.episodes.fetchHistory(episode)
        }
        .onBecomeActive {
            await reload()
        }
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
                .italic(episode.title == nil)
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
                MediaDetailsRow(
                    String(localized: "Network", comment: "The network that airs the show"),
                    value: network
                )
            }

            if !series.genres.isEmpty {
                MediaDetailsRow(
                    String(localized: "Genre", comment: "Genres of the movie/series"),
                    value: series.genreLabel
                )
            }

            if episode.isDownloaded {
                Group {
                    MediaDetailsRow(String(localized: "Video"), value: mediaDetailsVideoQuality(episodeFile))
                    MediaDetailsRow(String(localized: "Audio"), value: mediaDetailsAudioQuality(episodeFile))

                    if let subtitles = mediaDetailsSubtitles(episodeFile, deviceType) {
                        MediaDetailsRow(String(localized: "Subtitles"), value: subtitles)
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
                    withAnimation(.snappy) { descriptionTruncated = false }
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
                ToolbarMonitorButton(monitored: Binding<Bool>(
                    get: { episode.monitored },
                    set: { episode.monitored = $0 }
                ))
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
            .tint(.primary)
            .menuIndicator(.hidden)
        }
    }

    var actions: some View {
        HStack(spacing: 24) {
            Button {
                Task { await dispatchSearch() }
            } label: {
                ButtonLabel(
                    text: String(localized: "Automatic"),
                    icon: "magnifyingglass",
                    isLoading: dispatchingSearch
                )
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .allowsHitTesting(!instance.series.isWorking)

            NavigationLink(
                value: SeriesPath.releases(series.id, nil, episodeId)
            ) {
                ButtonLabel(text: String(localized: "Interactive"), icon: "person.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 450)
    }

    var deleteFileButton: some View {
        Button("Delete File", systemImage: "trash", role: .destructive) {
            showDeleteConfirmation = true
        }.tint(.red)
    }

    var file: some View {
        Section {
            if let file = episodeFile {
                LabeledGroupBox {
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
                .onTapGesture { fileSheet = file }
                .contextMenu { deleteFileButton }
                .popoverTip(DeleteFileTip())
                .padding(.bottom)
            }
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

    var history: some View {
        Section {
            ForEach(instance.episodes.history.filter { $0.episodeId == episode.id }) { event in
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
                    dynamic: event.eventType == .grabbed ? [.medium] : [.fraction(0.25)]
                )
        }
    }
}

extension EpisodeView {
    func setEpisodeState() {
        if let episode = instance.episodes.items.first(where: { $0.id == episodeId }) {
            self.episode = episode
            self.episodeFile = instance.files.items.first { $0.id == episode.episodeFileId }
        }
    }

    func toggleMonitor() async {
        guard let index = instance.episodes.items.firstIndex(where: { $0.id == episode.id }) else {
            return
        }

        episode.monitored.toggle()
        instance.episodes.items[index].monitored.toggle()

        guard await instance.episodes.monitor([episode.id], episode.monitored) else {
            return
        }

        dependencies.toast.show(episode.monitored ? .monitored : .unmonitored)
    }

    func reload() async {
        async let fetchEpisodes: () = instance.episodes.fetch(series)
        async let fetchFiles: () = instance.files.fetch(series)
        async let fetchHistory: () = instance.episodes.fetchHistory(episode)

        (_, _, _) = await (fetchEpisodes, fetchFiles, fetchHistory)

        setEpisodeState()
    }

    func dispatchSearch() async {
        defer { dispatchingSearch = false }
        dispatchingSearch = true

        guard await instance.series.command(
            .episodeSearch([episode.id])) else {
            return
        }

        dependencies.toast.show(.episodeSearchQueued)

        TelemetryDeck.signal("automaticSearchDispatched", parameters: ["type": "episode"])
        maybeAskForReview()
    }

    func deleteEpisode() async {
        guard let episodeFile else { return }

        if await instance.files.delete(episodeFile) {
            dependencies.toast.show(.fileDeleted)
            await reload()
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
