import Foundation

extension API {
    static var live: Self {
        .init(radarr: .live, sonarr: .live, instance: .live)
    }
}

extension RadarrAPI {
    static var live: Self {
        .init(fetch: { instance in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/movie")

            var movies: [Movie] = try await API.request(url: url, instance: instance, timeout: .slow)
            movies.stamp(instance.id)
            return movies
        }, lookup: { instance, query in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/movie/lookup")
                .appending(queryItems: [.init(name: "term", value: query)])

            return try await API.request(url: url, instance: instance, timeout: .sluggish)
        }, releases: { movieId, instance in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/release")
                .appending(queryItems: [.init(name: "movieId", value: String(movieId))])

            return try await API.request(url: url, instance: instance, timeout: .releaseSearch)
        }, movie: { movieId, instance in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/movie")
                .appending(path: String(movieId))

            var movie: Movie = try await API.request(url: url, instance: instance)
            movie.stamp(instance.id)
            return movie
        }, history: { movieId, instance in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/history/movie")
                .appending(queryItems: [.init(name: "movieId", value: String(movieId))])

            return try await API.request(url: url, instance: instance)
        }, files: { movieId, instance in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/moviefile")
                .appending(queryItems: [.init(name: "movieId", value: String(movieId))])

            return try await API.request(url: url, instance: instance)
        }, extraFiles: { movieId, instance in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/extrafile")
                .appending(queryItems: [.init(name: "movieId", value: String(movieId))])

            return try await API.request(url: url, instance: instance)
        }, add: { movie, instance in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/movie")

            return try await API.request(method: .post, url: url, body: movie, instance: instance)
        }, update: { movie, moveFiles, instance in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/movie/editor")

            let body = MovieEditorResource(
                movieIds: [movie.id],
                monitored: movie.monitored,
                qualityProfileId: movie.qualityProfileId,
                minimumAvailability: movie.minimumAvailability,
                rootFolderPath: movie.rootFolderPath,
                tags: movie.tags,
                applyTags: "replace",
                moveFiles: moveFiles ? true : nil
            )

            return try await API.request(method: .put, url: url, body: body, instance: instance)
        }, delete: { movie, addExclusion, deleteFildes, instance in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/movie")
                .appending(path: String(movie.id))
                .appending(queryItems: [
                    .init(name: "deleteFiles", value: deleteFildes ? "true" : "false"),
                    .init(name: "addImportExclusion", value: addExclusion ? "true" : "false"),
                ])

            return try await API.request(method: .delete, url: url, instance: instance)
        }, deleteFile: { file, instance in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/moviefile")
                .appending(path: String(file.id))

            return try await API.request(method: .delete, url: url, instance: instance)
        }, calendar: { start, end, instance in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/calendar")
                .appending(queryItems: [
                    .init(name: "unmonitored", value: "true"),
                    .init(name: "start", value: start.formatted(.iso8601)),
                    .init(name: "end", value: end.formatted(.iso8601)),
                ])

            var movies: [Movie] = try await API.request(url: url, instance: instance, timeout: .slow)
            movies.stamp(instance.id)
            return movies
        })
    }
}

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

extension InstanceAPI {
    static var live: Self {
        .init(command: { command, instance in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/command")

            return try await API.request(method: .post, url: url, body: command.payload, instance: instance)
        }, downloadRelease: { payload, instance in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/release")

            return try await API.request(method: .post, url: url, body: payload, instance: instance, timeout: .sluggish)
        }, status: { instance in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/system/status")

            return try await API.request(url: url, instance: instance)
        }, rootFolders: { instance in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/rootfolder")

            return try await API.request(url: url, instance: instance, timeout: .slow)
        }, qualityProfiles: { instance in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/qualityprofile")
            return try await API.request(url: url, instance: instance)
        }, diskSpace: { instance in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/diskspace")

            return try await API.request(url: url, instance: instance)
        }, tags: { instance in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/tag")

            return try await API.request(url: url, instance: instance)
        }, queue: { instance in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/queue")
                .appending(queryItems: [
                    .init(name: "includeMovie", value: "true"),
                    .init(name: "includeSeries", value: "true"),
                    .init(name: "includeEpisode", value: "true"),
                    .init(name: "pageSize", value: "250"),
                ])

            var items: QueueItems = try await API.request(url: url, instance: instance)
            items.records.stamp(instance.id)
            return items
        }, deleteQueueTask: { task, remove, block, search, instance in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/queue")
                .appending(path: String(task))
                .appending(queryItems: [
                    .init(name: "removeFromClient", value: remove ? "true" : "false"),
                    .init(name: "blocklist", value: block ? "true" : "false"),
                    .init(name: "skipRedownload", value: search ? "false" : "true"),
                ])

            return try await API.request(method: .delete, url: url, instance: instance)
        }, importableFiles: { downloadId, instance in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/manualimport")
                .appending(queryItems: [
                    .init(name: "downloadId", value: downloadId),
                    .init(name: "filterExistingFiles", value: "false"),
                ])

            return try await API.request(url: url, instance: instance, timeout: .sluggish)
        }, history: { type, page, limit, instance in
            var url = try await instance.baseURL()
                .appending(path: "/api/v3/history")
                .appending(queryItems: [
                    .init(name: "page", value: String(page)),
                    .init(name: "pageSize", value: String(limit)),
                ])

            if let type {
                url = url.appending(queryItems: [.init(name: "eventType", value: String(type))])
            }

            var history: MediaHistory = try await API.request(url: url, instance: instance)
            history.records.stamp(instance.id)
            return history
        }, notifications: { instance in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/notification")

            return try await API.request(url: url, instance: instance)
        }, createNotification: { model, instance in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/notification")

            return try await API.request(method: .post, url: url, body: model, instance: instance)
        }, updateNotification: { model, instance in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/notification")
                .appending(path: String(model.id ?? 0))

            return try await API.request(method: .put, url: url, body: model, instance: instance)
        }, deleteNotification: { model, instance in
            let url = try await instance.baseURL()
                .appending(path: "/api/v3/notification")
                .appending(path: String(model.id ?? 0))

            return try await API.request(method: .delete, url: url, instance: instance)
        })
    }
}
