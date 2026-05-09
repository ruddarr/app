import Foundation

extension API {
    static var live: Self {
        .init(fetchMovies: { instance in
            let url = try instance.baseURL()
                .appending(path: "/api/v3/movie")

            var movies: [Movie] = try await request(url: url, headers: instance.auth, timeout: instance.timeout(.slow))
            for i in movies.indices { movies[i].instanceId = instance.id }
            return movies
        }, lookupMovies: { instance, query in
            let url = try instance.baseURL()
                .appending(path: "/api/v3/movie/lookup")
                .appending(queryItems: [.init(name: "term", value: query)])

            return try await request(url: url, headers: instance.auth)
        }, lookupMovieReleases: { movieId, instance in
            let url = try instance.baseURL()
                .appending(path: "/api/v3/release")
                .appending(queryItems: [.init(name: "movieId", value: String(movieId))])

            return try await request(url: url, headers: instance.auth, timeout: instance.timeout(.releaseSearch))
        }, getMovie: { movieId, instance in
            let url = try instance.baseURL()
                .appending(path: "/api/v3/movie")
                .appending(path: String(movieId))

            return try await request(url: url, headers: instance.auth)
        }, getMovieHistory: { movieId, instance in
            let url = try instance.baseURL()
                .appending(path: "/api/v3/history/movie")
                .appending(queryItems: [.init(name: "movieId", value: String(movieId))])

            return try await request(url: url, headers: instance.auth)
        }, getMovieFiles: { movieId, instance in
            let url = try instance.baseURL()
                .appending(path: "/api/v3/moviefile")
                .appending(queryItems: [.init(name: "movieId", value: String(movieId))])

            return try await request(url: url, headers: instance.auth)
        }, getMovieExtraFiles: { movieId, instance in
            let url = try instance.baseURL()
                .appending(path: "/api/v3/extrafile")
                .appending(queryItems: [.init(name: "movieId", value: String(movieId))])

            return try await request(url: url, headers: instance.auth)
        }, addMovie: { movie, instance in
            let url = try instance.baseURL()
                .appending(path: "/api/v3/movie")

            return try await request(method: .post, url: url, headers: instance.auth, body: movie)
        }, updateMovie: { movie, moveFiles, instance in
            let url = try instance.baseURL()
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

            return try await request(method: .put, url: url, headers: instance.auth, body: body)
        }, deleteMovie: { movie, addExclusion, deleteFildes, instance in
            let url = try instance.baseURL()
                .appending(path: "/api/v3/movie")
                .appending(path: String(movie.id))
                .appending(queryItems: [
                    .init(name: "deleteFiles", value: deleteFildes ? "true" : "false"),
                    .init(name: "addImportExclusion", value: addExclusion ? "true" : "false"),
                ])

            return try await request(method: .delete, url: url, headers: instance.auth)
        }, deleteMovieFile: { file, instance in
            let url = try instance.baseURL()
                .appending(path: "/api/v3/moviefile")
                .appending(path: String(file.id))

            return try await request(method: .delete, url: url, headers: instance.auth)
        },

        fetchArtists: { instance in
            let url = try instance.baseURL()
                .appending(path: "/api/v1/artist")

            var artists: [Artist] = try await request(url: url, headers: instance.auth, timeout: instance.timeout(.slow))
            for i in artists.indices { artists[i].instanceId = instance.id }
            return artists
        },
        fetchAlbums: { artistId, instance in
            let url = try instance.baseURL()
                .appending(path: "/api/v1/album")
                .appending(queryItems: [
                    .init(name: "artistId", value: "\(artistId)")
                ])

            var albums: [Album] = try await request(url: url, headers: instance.auth, timeout: instance.timeout(.slow))
            for i in albums.indices { albums[i].instanceId = instance.id }
            return albums
        },
        fetchAlbumFiles: { albumId, instance in
            let url = try instance.baseURL()
                .appending(path: "/api/v1/trackfile")
                .appending(queryItems: [
                    .init(name: "albumId", value: String(albumId))
                ])

            return try await request(url: url, headers: instance.auth, timeout: instance.timeout(.slow))
        },
        lookupArtists: { instance, query in
            let url = try instance.baseURL()
                .appending(path: "/api/v1/artist/lookup")
                .appending(queryItems: [.init(name: "term", value: query)])

            return try await request(url: url, headers: instance.auth, timeout: instance.timeout(.slow))
        },

        fetchSeries: { instance in
            let url = try instance.baseURL()
                .appending(path: "/api/v3/series")

            var series: [Series] = try await request(url: url, headers: instance.auth, timeout: instance.timeout(.slow))
            for i in series.indices { series[i].instanceId = instance.id }
            return series
        }, fetchEpisodes: { seriesId, instance in
            let url = try instance.baseURL()
                .appending(path: "/api/v3/episode")
                .appending(queryItems: [.init(name: "seriesId", value: String(seriesId))])

            var episodes: [Episode] = try await request(url: url, headers: instance.auth)
            for i in episodes.indices { episodes[i].instanceId = instance.id }
            return episodes
        }, fetchEpisodeFiles: { seriesId, instance in
            let url = try instance.baseURL()
                .appending(path: "/api/v3/episodeFile")
                .appending(queryItems: [.init(name: "seriesId", value: String(seriesId))])

            return try await request(url: url, headers: instance.auth)
        }, lookupSeries: { instance, query in
            let url = try instance.baseURL()
                .appending(path: "/api/v3/series/lookup")
                .appending(queryItems: [.init(name: "term", value: query)])

            return try await request(url: url, headers: instance.auth, timeout: instance.timeout(.slow))
        }, lookupSeriesReleases: { seriesId, seasonId, episodeId, instance in
            var url = URL(string: instance.url)!
                .appending(path: "/api/v3/release")

            if let episode = episodeId {
                url = url.appending(queryItems: [.init(name: "episodeId", value: String(episode))])
            } else {
                url = url.appending(queryItems: [.init(name: "seriesId", value: String(seriesId!)), .init(name: "seasonNumber", value: String(seasonId!))])
            }

            return try await request(url: url, headers: instance.auth, timeout: instance.timeout(.releaseSearch))
        }, getSeries: { series, instance in
            let url = try instance.baseURL()
                .appending(path: "/api/v3/series")
                .appending(path: String(series))

            return try await request(url: url, headers: instance.auth)
        }, addSeries: { series, instance in
            let url = try instance.baseURL()
                .appending(path: "/api/v3/series")

            return try await request(method: .post, url: url, headers: instance.auth, body: series)
        }, pushSeries: { series, instance in
            let url = try instance.baseURL()
                .appending(path: "/api/v3/series")
                .appending(path: String(series.id))

            return try await request(method: .put, url: url, headers: instance.auth, body: series)
        }, updateSeries: { series, moveFiles, instance in
            let url = try instance.baseURL()
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

            return try await request(method: .put, url: url, headers: instance.auth, body: body)
        }, deleteSeries: { series, addExclusion, deleteFiles, instance in
            let url = try instance.baseURL()
                .appending(path: "/api/v3/series")
                .appending(path: String(series.id))
                .appending(queryItems: [
                    .init(name: "deleteFiles", value: deleteFiles ? "true" : "false"),
                    .init(name: "addImportListExclusion", value: addExclusion ? "true" : "false"),
                ])

            return try await request(method: .delete, url: url, headers: instance.auth)
        }, monitorEpisode: { ids, monitored, instance in
            let url = try instance.baseURL()
                .appending(path: "/api/v3/episode/monitor")

            let body = EpisodesMonitorResource(episodeIds: ids, monitored: monitored)

            return try await request(method: .put, url: url, headers: instance.auth, body: body)
        }, getEpisodeHistory: { id, instance in
            let url = try instance.baseURL()
                .appending(path: "/api/v3/history")
                .appending(queryItems: [.init(name: "episodeId", value: String(id))])

            return try await request(url: url, headers: instance.auth)
        }, deleteEpisodeFile: { file, instance in
            let url = try instance.baseURL()
                .appending(path: "/api/v3/episodefile")
                .appending(path: String(file.id))

            return try await request(method: .delete, url: url, headers: instance.auth)
        }, deleteEpisodeFiles: { files, instance in
            let url = try instance.baseURL()
                .appending(path: "/api/v3/episodefile/bulk")

            let body = EpisodeDeleteResource(episodeFileIds: files.map(\.id))

            return try await request(method: .delete, url: url, headers: instance.auth, body: body)
        }, getArtist: { artistId, instance in
            let url = try instance.baseURL()
                .appending(path: "/api/v1/artist")
                .appending(path: String(artistId))

            return try await request(url: url, headers: instance.auth)
        }, addArtist: { artist, instance in
            let url = try instance.baseURL()
                .appending(path: "/api/v1/artist")
                .appending(path: String(artist.id))

            return try await request(method: .post, url: url, headers: instance.auth, body: artist)
        }, pushArtist: { artist, instance in
            let url = try instance.baseURL()
                .appending(path: "/api/v1/artist")
                .appending(path: String(artist.id))

            return try await request(method: .put, url: url, headers: instance.auth, body: artist)
        }, updateArtist: { artist, moveFiles, instance in
            let url = try instance.baseURL()
                .appending(path: "/api/v1/artist")
                .appending(path: String(artist.id))

            let body = ArtistEditorResource(
                artistsIds: [artist.id],
                monitored: artist.monitored,
                monitorNewItems: artist.monitorNewItems ?? .none,
                qualityProfileId: artist.qualityProfileId,
                metadataProfileId: artist.metadataProfileId,
                rootFolderPath: artist.rootFolderPath,
                tags: artist.tags,
                applyTags: "replace",
                moveFiles: moveFiles ? true : nil,
            )

            return try await request(method: .post, url: url, headers: instance.auth, body: body)
        }, deleteArtist: { artist, addExclusion, deleteFiles, instance in
            let url = try instance.baseURL()
                .appending(path: "/api/v1/artist")
                .appending(path: String(artist.id))
                .appending(queryItems: [
                    .init(name: "deleteFiles", value: deleteFiles ? "true" : "false"),
                    .init(name: "addImportListExclusion", value: addExclusion ? "true" : "false"),
                ])

            return try await request(method: .delete, url: url, headers: instance.auth)
        }, albumCalendar: { start, end, instance in
            let url = try instance.baseURL()
                .appending(path: "/api/v1/calendar")
                .appending(queryItems: [
                    .init(name: "unmonitored", value: "true"),
                    .init(name: "start", value: start.formatted(.iso8601)),
                    .init(name: "end", value: end.formatted(.iso8601)),
                ])

            var albums: [Album] = try await request(url: url, headers: instance.auth, timeout: instance.timeout(.slow))
            for i in albums.indices { albums[i].instanceId = instance.id }
            return albums
        }, movieCalendar: { start, end, instance in
            let url = try instance.baseURL()
                .appending(path: "/api/v3/calendar")
                .appending(queryItems: [
                    .init(name: "unmonitored", value: "true"),
                    .init(name: "start", value: start.formatted(.iso8601)),
                    .init(name: "end", value: end.formatted(.iso8601)),
                ])

            var movies: [Movie] = try await request(url: url, headers: instance.auth, timeout: instance.timeout(.slow))
            for i in movies.indices { movies[i].instanceId = instance.id }
            return movies
        }, episodeCalendar: { start, end, instance in
            let url = try instance.baseURL()
                .appending(path: "/api/v3/calendar")
                .appending(queryItems: [
                    .init(name: "unmonitored", value: "true"),
                    .init(name: "includeSeries", value: "true"),
                    .init(name: "start", value: start.formatted(.iso8601)),
                    .init(name: "end", value: end.formatted(.iso8601)),
                ])

            var episodes: [Episode] = try await request(url: url, headers: instance.auth, timeout: instance.timeout(.slow))
            for i in episodes.indices { episodes[i].instanceId = instance.id }
            return episodes
        }, command: { command, instance in
            let apiVersion = instance.type == .lidarr ? "v1" : "v3"
            let url = try instance.baseURL()
                .appending(path: "/api/\(apiVersion)/command")

            return try await request(method: .post, url: url, headers: instance.auth, body: command.payload)
        }, downloadRelease: { payload, instance in
            let apiVersion = instance.type == .lidarr ? "v1" : "v3"
            let url = try instance.baseURL()
                .appending(path: "/api/\(apiVersion)/release")

            return try await request(method: .post, url: url, headers: instance.auth, body: payload, timeout: instance.timeout(.releaseDownload))
        }, systemStatus: { instance in
            let apiVersion = instance.type == .lidarr ? "v1" : "v3"
            let url = try instance.baseURL()
                .appending(path: "/api/\(apiVersion)/system/status")

            return try await request(url: url, headers: instance.auth)
        }, rootFolders: { instance in
            let apiVersion = instance.type == .lidarr ? "v1" : "v3"
            let url = try instance.baseURL()
                .appending(path: "/api/\(apiVersion)/rootfolder")

            return try await request(url: url, headers: instance.auth, timeout: instance.timeout(.slow))
        }, qualityProfiles: { instance in
            let apiVersion = instance.type == .lidarr ? "v1" : "v3"
            let url = try instance.baseURL()
                .appending(path: "/api/\(apiVersion)/qualityprofile")
            return try await request(url: url, headers: instance.auth)
        }, getTags: { instance in
            let apiVersion = instance.type == .lidarr ? "v1" : "v3"
            let url = try instance.baseURL()
                .appending(path: "/api/\(apiVersion)/tag")

            return try await request(url: url, headers: instance.auth)
        }, fetchQueueTasks: { instance in
            let apiVersion = instance.type == .lidarr ? "v1" : "v3"
            let url = try instance.baseURL()
                .appending(path: "/api/\(apiVersion)/queue")
                .appending(queryItems: [
                    .init(name: "includeMovie", value: "true"),
                    .init(name: "includeSeries", value: "true"),
                    .init(name: "includeEpisode", value: "true"),
                    .init(name: "includeArtist", value: "true"),
                    .init(name: "includeAlbum", value: "true"),
                    .init(name: "includeUnknownArtistItems", value: "true"),
                    .init(name: "pageSize", value: "100"),
                ])

            var items: QueueItems = try await request(url: url, headers: instance.auth)
            for i in items.records.indices { items.records[i].instanceId = instance.id }
            return items
        }, deleteQueueTask: { task, remove, block, search, instance in
            let apiVersion = instance.type == .lidarr ? "v1" : "v3"
            let url = try instance.baseURL()
                .appending(path: "/api/\(apiVersion)/queue")
                .appending(path: String(task))
                .appending(queryItems: [
                    .init(name: "removeFromClient", value: remove ? "true" : "false"),
                    .init(name: "blocklist", value: block ? "true" : "false"),
                    .init(name: "skipRedownload", value: search ? "false" : "true"),
                ])

            return try await request(method: .delete, url: url, headers: instance.auth)
        }, fetchImportableFiles: { downloadId, instance in
            let apiVersion = instance.type == .lidarr ? "v1" : "v3"
            let url = try instance.baseURL()
                .appending(path: "/api/\(apiVersion)/manualimport")
                .appending(queryItems: [
                    .init(name: "downloadId", value: downloadId),
                    .init(name: "filterExistingFiles", value: "false"),
                ])

            return try await request(url: url, headers: instance.auth)
        }, fetchHistory: { type, page, limit, instance in
            let apiVersion = instance.type == .lidarr ? "v1" : "v3"
            var url = URL(string: instance.url)!
                .appending(path: "/api/\(apiVersion)/history")
                .appending(queryItems: [
                    .init(name: "page", value: String(page)),
                    .init(name: "pageSize", value: String(limit)),
                ])

            if let type {
                url = url.appending(queryItems: [.init(name: "eventType", value: String(type))])
            }

            var history: MediaHistory = try await request(url: url, headers: instance.auth)
            for i in history.records.indices { history.records[i].instanceId = instance.id }
            return history
        }, fetchNotifications: { instance in
            let apiVersion = instance.type == .lidarr ? "v1" : "v3"
            let url = try instance.baseURL()
                .appending(path: "/api/\(apiVersion)/notification")

            return try await request(url: url, headers: instance.auth)
        }, createNotification: { model, instance in
            let apiVersion = instance.type == .lidarr ? "v1" : "v3"
            let url = try instance.baseURL()
                .appending(path: "/api/\(apiVersion)/notification")

            return try await request(method: .post, url: url, headers: instance.auth, body: model)
        }, updateNotification: { model, instance in
            let apiVersion = instance.type == .lidarr ? "v1" : "v3"
            let url = try instance.baseURL()
                .appending(path: "/api/\(apiVersion)/notification")
                .appending(path: String(model.id ?? 0))

            return try await request(method: .put, url: url, headers: instance.auth, body: model)
        }, deleteNotification: { model, instance in
            let apiVersion = instance.type == .lidarr ? "v1" : "v3"
            let url = try instance.baseURL()
                .appending(path: "/api/\(apiVersion)/notification")
                .appending(path: String(model.id ?? 0))

            return try await request(method: .delete, url: url, headers: instance.auth)
        })
    }
}
