import Foundation

extension API {
    static var live: Self {
        .init(radarr: .live, sonarr: .live, chaptarr: .live, instance: .live)
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
            let url = try await instance.apiURL("command")

            return try await API.request(method: .post, url: url, body: command.payload, instance: instance)
        }, downloadRelease: { payload, instance in
            let url = try await instance.apiURL("release")

            return try await API.request(method: .post, url: url, body: payload, instance: instance, timeout: .sluggish)
        }, status: { instance in
            let url = try await instance.apiURL("system/status")

            return try await API.request(url: url, instance: instance)
        }, rootFolders: { instance in
            let url = try await instance.apiURL("rootfolder")

            return try await API.request(url: url, instance: instance, timeout: .slow)
        }, qualityProfiles: { instance in
            let url = try await instance.apiURL("qualityprofile")

            return try await API.request(url: url, instance: instance)
        }, diskSpace: { instance in
            let url = try await instance.apiURL("diskspace")

            return try await API.request(url: url, instance: instance)
        }, tags: { instance in
            let url = try await instance.apiURL("tag")

            return try await API.request(url: url, instance: instance)
        }, queue: { instance in
            let url = try await instance.apiURL("queue")
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
            let url = try await instance.apiURL("queue")
                .appending(path: String(task))
                .appending(queryItems: [
                    .init(name: "removeFromClient", value: remove ? "true" : "false"),
                    .init(name: "blocklist", value: block ? "true" : "false"),
                    .init(name: "skipRedownload", value: search ? "false" : "true"),
                ])

            return try await API.request(method: .delete, url: url, instance: instance)
        }, importableFiles: { downloadId, instance in
            let url = try await instance.apiURL("manualimport")
                .appending(queryItems: [
                    .init(name: "downloadId", value: downloadId),
                    .init(name: "filterExistingFiles", value: "false"),
                ])

            return try await API.request(url: url, instance: instance, timeout: .sluggish)
        }, history: { type, page, limit, instance in
            var url = try await instance.apiURL("history")
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
            let url = try await instance.apiURL("notification")

            return try await API.request(url: url, instance: instance)
        }, createNotification: { model, instance in
            let url = try await instance.apiURL("notification")

            return try await API.request(method: .post, url: url, body: model, instance: instance)
        }, updateNotification: { model, instance in
            let url = try await instance.apiURL("notification")
                .appending(path: String(model.id ?? 0))

            return try await API.request(method: .put, url: url, body: model, instance: instance)
        }, deleteNotification: { model, instance in
            let url = try await instance.apiURL("notification")
                .appending(path: String(model.id ?? 0))

            return try await API.request(method: .delete, url: url, instance: instance)
        })
    }
}

extension ChaptarrAPI {
    static var live: Self {
        .init(fetch: { instance in
            let url = try await instance.apiURL("book")
                .appending(queryItems: [
                    .init(name: "monitored", value: "true"),
                    .init(name: "include", value: "author,links"),
                ])

            var books: [Book] = try await API.request(url: url, instance: instance, timeout: .slow)
            books.stamp(instance.id)
            return books
        }, page: { instance, query, offset, pageSize in
            var items: [URLQueryItem] = [
                .init(name: "offset", value: String(offset)),
                .init(name: "pageSize", value: String(pageSize)),
                .init(name: "sortKey", value: query.sortKey),
                .init(name: "sortDirection", value: query.sortDirection),
                .init(name: "mediaType", value: query.mediaType),
                .init(name: "include", value: "author"),
            ]

            if query.includeUnmonitored { items.append(.init(name: "includeUnmonitored", value: "true")) }
            if let monitored = query.monitored { items.append(.init(name: "monitored", value: String(monitored))) }
            if let downloaded = query.downloaded { items.append(.init(name: "downloaded", value: String(downloaded))) }
            if let missing = query.missing { items.append(.init(name: "missing", value: String(missing))) }

            let url = try await instance.apiURL("book/paged").appending(queryItems: items)

            var page: BooksPage = try await API.request(url: url, instance: instance, timeout: .slow)
            page.records.stamp(instance.id)
            return page
        }, search: { instance, term in
            try await searchLibrary(term, instance)
        }, lookup: { instance, query in
            let url = try await instance.apiURL("book/lookup")
                .appending(queryItems: [.init(name: "term", value: query)])

            return try await API.request(url: url, instance: instance, timeout: .sluggish)
        }, book: { bookId, instance in
            let url = try await instance.apiURL("book").appending(path: String(bookId))

            var book: Book = try await API.request(url: url, instance: instance, timeout: .sluggish)
            book.stamp(instance.id)
            return book
        }, series: { authorId, instance in
            let url = try await instance.apiURL("series")
                .appending(queryItems: [.init(name: "authorId", value: String(authorId))])

            return try await API.request(url: url, instance: instance, timeout: .slow)
        }, files: { bookId, instance in
            let url = try await instance.apiURL("bookfile")
                .appending(queryItems: [.init(name: "bookId", value: String(bookId))])

            return try await API.request(url: url, instance: instance)
        }, history: { authorId, bookId, instance in
            let url = try await instance.apiURL("history/author")
                .appending(queryItems: [
                    .init(name: "authorId", value: String(authorId)),
                    .init(name: "bookId", value: String(bookId)),
                ])

            return try await API.request(url: url, instance: instance)
        }, add: { book, instance in
            let url = try await instance.apiURL("book")

            return try await API.request(method: .post, url: url, body: book, instance: instance, timeout: .sluggish)
        }, monitor: { ids, monitored, instance in
            let url = try await instance.apiURL("book/monitor")

            let body = BooksMonitorResource(bookIds: ids, monitored: monitored)

            return try await API.request(method: .put, url: url, body: body, instance: instance)
        }, deleteFile: { file, instance in
            let url = try await instance.apiURL("bookfile")
                .appending(path: String(file.id))

            return try await API.request(method: .delete, url: url, instance: instance)
        }, metadataProfiles: { instance in
            let url = try await instance.apiURL("metadataprofile")

            return try await API.request(url: url, instance: instance)
        }, calendar: { start, end, instance in
            let url = try await instance.apiURL("calendar")
                .appending(queryItems: [
                    .init(name: "unmonitored", value: "true"),
                    .init(name: "includeAuthor", value: "true"),
                    .init(name: "start", value: start.formatted(.iso8601)),
                    .init(name: "end", value: end.formatted(.iso8601)),
                ])

            var books: [Book] = try await API.request(url: url, instance: instance, timeout: .slow)
            books.stamp(instance.id)
            return books
        })
    }

    private static func searchLibrary(_ term: String, _ instance: Instance) async throws -> [Book] {
        let searchURL = try await instance.apiURL("library/search")
            .appending(queryItems: [
                .init(name: "term", value: term),
                .init(name: "limit", value: "50"),
            ])

        let result: BookSearchResult = try await API.request(url: searchURL, instance: instance, timeout: .slow)

        var books: [Book] = []

        if !result.books.isEmpty {
            let url = try await instance.apiURL("book")
                .appending(queryItems: result.books.map { .init(name: "bookIds", value: String($0.id)) })

            books = (try? await API.request(url: url, instance: instance, timeout: .slow)) ?? []
        }

        try Task.checkCancellation()

        let authors = result.authors.prefix(10)

        let catalogs: [Int: [Book]] = await withTaskGroup(of: (Int, [Book]).self) { group in
            for author in authors {
                group.addTask {
                    guard let url = try? await instance.apiURL("book")
                        .appending(queryItems: [.init(name: "authorId", value: String(author.id))])
                    else {
                        return (author.id, [])
                    }

                    let fetched: [Book]? = try? await API.request(url: url, instance: instance, timeout: .slow)

                    return (author.id, fetched ?? [])
                }
            }

            var catalogs: [Int: [Book]] = [:]

            for await (authorId, fetched) in group {
                catalogs[authorId] = fetched
            }

            return catalogs
        }

        try Task.checkCancellation()

        var bookIds = Set(books.map(\.id))

        for author in authors {
            books.append(contentsOf: (catalogs[author.id] ?? [])
                .filter { bookIds.insert($0.id).inserted }
                .sorted { $0.sortTitle < $1.sortTitle }
            )
        }

        let matchNames = result.books.reduce(into: [Int: String]()) { $0[$1.id] = $1.authorName }
        let authorNames = authors.reduce(into: [Int: String]()) { $0[$1.id] = $1.name }

        for index in books.indices where books[index].author == nil {
            guard let name = matchNames[books[index].id] ?? authorNames[books[index].authorId] else { continue }
            books[index].author = .init(id: books[index].authorId, authorName: name)
        }

        books.stamp(instance.id)

        return books
    }
}
