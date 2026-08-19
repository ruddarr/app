import Foundation

extension SonarrAPI {
    static var live: Self {
        .init(fetch: { instance in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/series")

            var series: [Series] = try await API.request(url: url, instance: instance, timeout: .slow)
            series.stamp(instance.id)
            return series
        }, episodes: { seriesId, instance in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/episode")
                .appending(queryItems: [
                    .init(name: "seriesId", value: String(seriesId)),
                    .init(name: "includeEpisodeFile", value: "true"),
                ])

            var episodes: [Episode] = try await API.request(url: url, instance: instance)
            episodes.stamp(instance.id)
            return episodes
        }, lookup: { instance, query in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/series/lookup")
                .appending(queryItems: [.init(name: "term", value: query)])

            return try await API.request(url: url, instance: instance, timeout: .sluggish)
        }, releases: { seriesId, seasonId, episodeId, instance in
            var url = try await instance.baseURL()
                .appending(path: "/api/v3/release")

            if let episode = episodeId {
                url = url.appending(queryItems: [.init(name: "episodeId", value: String(episode))])
            } else {
                url = url.appending(queryItems: [.init(name: "seriesId", value: String(seriesId!)), .init(name: "seasonNumber", value: String(seasonId!))])
            }

            return try await API.request(url: url, instance: instance, timeout: .releaseSearch)
        }, series: { seriesId, instance in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/series")
                .appending(path: String(seriesId))

            var series: Series = try await API.request(url: url, instance: instance)
            series.stamp(instance.id)
            return series
        }, add: { series, instance in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/series")

            return try await API.request(method: .post, url: url, body: series, instance: instance)
        }, push: { series, instance in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/series")
                .appending(path: String(series.id))

            return try await API.request(method: .put, url: url, body: series, instance: instance)
        }, update: { series, moveFiles, instance in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/series/editor")

            let body = SeriesEditorResource(
                seriesIds: [series.id],
                monitored: series.monitored,
                monitorNewItems: series.monitorNewItems ?? .none,
                seriesType: series.seriesType,
                seasonFolder: series.seasonFolder,
                qualityProfileId: series.qualityProfileId,
                rootFolderPath: series.rootFolderPath,
                tags: series.tags,
                applyTags: "replace",
                moveFiles: moveFiles ? true : nil
            )

            return try await API.request(method: .put, url: url, body: body, instance: instance)
        }, delete: { series, addExclusion, deleteFiles, instance in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/series")
                .appending(path: String(series.id))
                .appending(queryItems: [
                    .init(name: "deleteFiles", value: deleteFiles ? "true" : "false"),
                    .init(name: "addImportListExclusion", value: addExclusion ? "true" : "false"),
                ])

            return try await API.request(method: .delete, url: url, instance: instance)
        }, monitorEpisode: { ids, monitored, instance in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/episode/monitor")

            let body = EpisodesMonitorResource(episodeIds: ids, monitored: monitored)

            return try await API.request(method: .put, url: url, body: body, instance: instance)
        }, episodeHistory: { id, instance in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/history")
                .appending(queryItems: [.init(name: "episodeId", value: String(id))])

            return try await API.request(url: url, instance: instance)
        }, deleteEpisodeFile: { file, instance in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/episodefile")
                .appending(path: String(file.id))

            return try await API.request(method: .delete, url: url, instance: instance)
        }, deleteEpisodeFiles: { files, instance in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/episodefile/bulk")

            let body = EpisodeDeleteResource(episodeFileIds: files.map(\.id))

            return try await API.request(method: .delete, url: url, body: body, instance: instance)
        }, calendar: { start, end, instance in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/calendar")
                .appending(queryItems: [
                    .init(name: "unmonitored", value: "true"),
                    .init(name: "includeSeries", value: "true"),
                    .init(name: "start", value: start.formatted(.iso8601)),
                    .init(name: "end", value: end.formatted(.iso8601)),
                ])

            var episodes: [Episode] = try await API.request(url: url, instance: instance, timeout: .slow)
            episodes.stamp(instance.id)
            return episodes
        })
    }
}
