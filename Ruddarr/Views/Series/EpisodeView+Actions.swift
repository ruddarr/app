import SwiftUI
import TelemetryDeck

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

        let original = episode.monitored
        episode.monitored = !original
        instance.episodes.items[index].monitored = !original

        guard await instance.episodes.monitor([episode.id], episode.monitored) else {
            if episode.monitored == !original {
                episode.monitored = original
            }
            if let i = instance.episodes.items.firstIndex(where: { $0.id == episode.id }),
               instance.episodes.items[i].monitored == !original {
                instance.episodes.items[i].monitored = original
            }
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

        Telemetry.record(.episodeSearchDispatched)
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
