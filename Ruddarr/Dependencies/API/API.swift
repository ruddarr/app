import os
import SwiftUI

struct API {
    var fetchMovies: (Instance) async throws -> [Movie]
    var lookupMovies: (_ instance: Instance, _ query: String) async throws -> [Movie]
    var lookupMovieReleases: (Movie.ID, Instance) async throws -> [MovieRelease]

    var getMovie: (Movie.ID, Instance) async throws -> Movie
    var getMovieHistory: (Movie.ID, Instance) async throws -> [MediaHistoryEvent]
    var getMovieFiles: (Movie.ID, Instance) async throws -> [MediaFile]
    var getMovieExtraFiles: (Movie.ID, Instance) async throws -> [MovieExtraFile]
    var addMovie: (Movie, Instance) async throws -> Movie
    var updateMovie: (Movie, Bool, Instance) async throws -> Empty
    var deleteMovie: (Movie, Bool, Instance) async throws -> Empty
    var deleteMovieFile: (MediaFile, Instance) async throws -> Empty

    var fetchSeries: (Instance) async throws -> [Series]
    var fetchEpisodes: (Series.ID, Instance) async throws -> [Episode]
    var fetchEpisodeFiles: (Series.ID, Instance) async throws -> [MediaFile]
    var lookupSeries: (_ instance: Instance, _ query: String) async throws -> [Series]
    var lookupSeriesReleases: (Series.ID?, Series.ID?, Episode.ID?, Instance) async throws -> [SeriesRelease]

    var getSeries: (Series.ID, Instance) async throws -> Series
    var addSeries: (Series, Instance) async throws -> Series
    var pushSeries: (Series, Instance) async throws -> Series
    var updateSeries: (Series, Bool, Instance) async throws -> Empty
    var deleteSeries: (Series, Bool, Instance) async throws -> Empty

    var monitorEpisode: ([Episode.ID], Bool, Instance) async throws -> Empty
    var getEpisodeHistory: (Episode.ID, Instance) async throws -> MediaHistory
    var deleteEpisodeFile: (MediaFile, Instance) async throws -> Empty

    var movieCalendar: (Date, Date, Instance) async throws -> [Movie]
    var episodeCalendar: (Date, Date, Instance) async throws -> [Episode]

    var command: (InstanceCommand, Instance) async throws -> Empty
    var downloadRelease: (DownloadReleaseCommand, Instance) async throws -> Empty

    var systemStatus: (Instance) async throws -> InstanceStatus
    var rootFolders: (Instance) async throws -> [InstanceRootFolders]
    var qualityProfiles: (Instance) async throws -> [InstanceQualityProfile]

    var fetchQueueTasks: (Instance) async throws -> QueueItems
    var deleteQueueTask: (QueueItem.ID, Bool, Bool, Bool, Instance) async throws -> Empty

    var fetchHistory: (Int?, Int, Int, Instance) async throws -> MediaHistory

    var fetchNotifications: (Instance) async throws -> [InstanceNotification]
    var createNotification: (InstanceNotification, Instance) async throws -> InstanceNotification
    var updateNotification: (InstanceNotification, Instance) async throws -> InstanceNotification
    var deleteNotification: (InstanceNotification, Instance) async throws -> Empty
    
    var fetchLocationsDiskSpace: (Instance) async throws -> [InstanceLocationDiskSpace]
}

// swiftlint:disable file_length
extension API {
    static var live: Self {
        .init(fetchMovies: { instance in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/movie")

            var movies: [Movie] = try await request(url: url, headers: instance.auth, timeout: instance.timeout(.slow))
            for i in movies.indices { movies[i].instanceId = instance.id }
            return movies
        }, lookupMovies: { instance, query in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/movie/lookup")
                .appending(queryItems: [.init(name: "term", value: query)])

            return try await request(url: url, headers: instance.auth)
        }, lookupMovieReleases: { movieId, instance in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/release")
                .appending(queryItems: [.init(name: "movieId", value: String(movieId))])

            return try await request(url: url, headers: instance.auth, timeout: instance.timeout(.releaseSearch))
        }, getMovie: { movieId, instance in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/movie")
                .appending(path: String(movieId))

            return try await request(url: url, headers: instance.auth)
        }, getMovieHistory: { movieId, instance in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/history/movie")
                .appending(queryItems: [.init(name: "movieId", value: String(movieId))])

            return try await request(url: url, headers: instance.auth)
        }, getMovieFiles: { movieId, instance in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/moviefile")
                .appending(queryItems: [.init(name: "movieId", value: String(movieId))])

            return try await request(url: url, headers: instance.auth)
        }, getMovieExtraFiles: { movieId, instance in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/extrafile")
                .appending(queryItems: [.init(name: "movieId", value: String(movieId))])

            return try await request(url: url, headers: instance.auth)
        }, addMovie: { movie, instance in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/movie")

            return try await request(method: .post, url: url, headers: instance.auth, body: movie)
        }, updateMovie: { movie, moveFiles, instance in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/movie/editor")

            let body = MovieEditorResource(
                movieIds: [movie.id],
                monitored: movie.monitored,
                qualityProfileId: movie.qualityProfileId,
                minimumAvailability: movie.minimumAvailability,
                rootFolderPath: movie.rootFolderPath,
                moveFiles: moveFiles ? true : nil
            )

            return try await request(method: .put, url: url, headers: instance.auth, body: body)
        }, deleteMovie: { movie, addExclusion, instance in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/movie")
                .appending(path: String(movie.id))
                .appending(queryItems: [
                    .init(name: "deleteFiles", value: "true"),
                    .init(name: "addImportExclusion", value: addExclusion ? "true" : "false"),
                ])

            return try await request(method: .delete, url: url, headers: instance.auth)
        }, deleteMovieFile: { file, instance in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/moviefile")
                .appending(path: String(file.id))

            return try await request(method: .delete, url: url, headers: instance.auth)
        }, fetchSeries: { instance in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/series")

            var series: [Series] = try await request(url: url, headers: instance.auth, timeout: instance.timeout(.slow))
            for i in series.indices { series[i].instanceId = instance.id }
            return series
        }, fetchEpisodes: { seriesId, instance in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/episode")
                .appending(queryItems: [.init(name: "seriesId", value: String(seriesId))])

            var episodes: [Episode] = try await request(url: url, headers: instance.auth)
            for i in episodes.indices { episodes[i].instanceId = instance.id }
            return episodes
        }, fetchEpisodeFiles: { seriesId, instance in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/episodeFile")
                .appending(queryItems: [.init(name: "seriesId", value: String(seriesId))])

            return try await request(url: url, headers: instance.auth)
        }, lookupSeries: { instance, query in
            let url = URL(string: instance.url)!
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
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/series")
                .appending(path: String(series))

            return try await request(url: url, headers: instance.auth)
        }, addSeries: { series, instance in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/series")

            return try await request(method: .post, url: url, headers: instance.auth, body: series)
        }, pushSeries: { series, instance in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/series")
                .appending(path: String(series.id))

            return try await request(method: .put, url: url, headers: instance.auth, body: series)
        }, updateSeries: { series, moveFiles, instance in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/series/editor")

            let body = SeriesEditorResource(
                seriesIds: [series.id],
                monitored: series.monitored,
                monitorNewItems: series.monitorNewItems ?? .none,
                seriesType: series.seriesType,
                seasonFolder: series.seasonFolder,
                qualityProfileId: series.qualityProfileId,
                rootFolderPath: series.rootFolderPath,
                moveFiles: moveFiles ? true : nil
            )

            return try await request(method: .put, url: url, headers: instance.auth, body: body)
        }, deleteSeries: { series, addExclusion, instance in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/series")
                .appending(path: String(series.id))
                .appending(queryItems: [
                    .init(name: "deleteFiles", value: "true"),
                    .init(name: "addImportListExclusion", value: addExclusion ? "true" : "false"),
                ])

            return try await request(method: .delete, url: url, headers: instance.auth)
        }, monitorEpisode: { ids, monitored, instance in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/episode/monitor")

            let body = EpisodesMonitorResource(episodeIds: ids, monitored: monitored)

            return try await request(method: .put, url: url, headers: instance.auth, body: body)
        }, getEpisodeHistory: { id, instance in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/history")
                .appending(queryItems: [.init(name: "episodeId", value: String(id))])

            return try await request(url: url, headers: instance.auth)
        }, deleteEpisodeFile: { file, instance in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/episodefile")
                .appending(path: String(file.id))

            return try await request(method: .delete, url: url, headers: instance.auth)
        }, movieCalendar: { start, end, instance in
            let url = URL(string: instance.url)!
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
            let url = URL(string: instance.url)!
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
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/command")

            return try await request(method: .post, url: url, headers: instance.auth, body: command.payload)
        }, downloadRelease: { payload, instance in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/release")

            return try await request(method: .post, url: url, headers: instance.auth, body: payload, timeout: instance.timeout(.releaseDownload))
        }, systemStatus: { instance in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/system/status")

            return try await request(url: url, headers: instance.auth)
        }, rootFolders: { instance in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/rootfolder")

            return try await request(url: url, headers: instance.auth, timeout: instance.timeout(.slow))
        }, qualityProfiles: { instance in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/qualityprofile")

            return try await request(url: url, headers: instance.auth)
        }, fetchQueueTasks: { instance in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/queue")
                .appending(queryItems: [
                    .init(name: "includeMovie", value: "true"),
                    .init(name: "includeSeries", value: "true"),
                    .init(name: "includeEpisode", value: "true"),
                    .init(name: "pageSize", value: "100"),
                ])

            var items: QueueItems = try await request(url: url, headers: instance.auth)
            for i in items.records.indices { items.records[i].instanceId = instance.id }
            return items
        }, deleteQueueTask: { task, remove, block, redownload, instance in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/queue")
                .appending(path: String(task))
                .appending(queryItems: [
                    .init(name: "removeFromClient", value: remove ? "true" : "false"),
                    .init(name: "blocklist", value: block ? "true" : "false"),
                    .init(name: "skipRedownload", value: redownload ? "true" : "false"),
                ])

            return try await request(method: .delete, url: url, headers: instance.auth)
        }, fetchHistory: { type, page, limit, instance in
            var url = URL(string: instance.url)!
                .appending(path: "/api/v3/history")
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
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/notification")

            return try await request(url: url, headers: instance.auth)
        }, createNotification: { model, instance in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/notification")

            return try await request(method: .post, url: url, headers: instance.auth, body: model)
        }, updateNotification: { model, instance in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/notification")
                .appending(path: String(model.id ?? 0))

            return try await request(method: .put, url: url, headers: instance.auth, body: model)
        }, deleteNotification: { model, instance in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/notification")
                .appending(path: String(model.id ?? 0))

            return try await request(method: .delete, url: url, headers: instance.auth)
        }, fetchLocationsDiskSpace: { instance in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/diskspace")
            return try await request(method: .get, url: url, headers: instance.auth)
        })
    }

    struct Empty: Encodable, Decodable { }

    // swiftlint:disable cyclomatic_complexity function_body_length
    fileprivate static func request<Body: Encodable, Response: Decodable>(
        method: HTTPMethod = .get,
        url: URL,
        headers: [String: String] = [:],
        body: Body? = nil,
        timeout: Double = 10,
        decoder: JSONDecoder = .init(),
        encoder: JSONEncoder = .init(),
        session: URLSession = .shared
    ) async throws -> Response {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601extended

        try await NetworkMonitor.shared.checkReachability()

        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.httpMethod = method.rawValue.uppercased()
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body {
            request.httpBody = try encoder.encode(body)
        }

        if !headers.isEmpty {
            for (key, value) in headers.sorted(by: { $0.key < $1.key }) {
                request.addValue(value, forHTTPHeaderField: key)
            }
        }

        leaveBreadcrumb(.debug, category: "api", message: "Sending request", data: [
            "url": url,
            "method": method.rawValue,
            "timeout": timeout,
        ])

        if let body {
            leaveBreadcrumb(.debug, category: "api", message: "Request body", data: ["body": body])
        }

        var json: Data?
        var response: URLResponse?

        do {
            (json, response) = try await session.data(for: request)
        } catch let cancellationError as CancellationError {
            // re-throw `CancellationError` so they can be handled elsewhere
            throw cancellationError
        } catch let urlError as URLError where urlError.code == .cancelled {
            // re-throw `URLError.cancelled` as `CancellationError`
            throw CancellationError()
        } catch let urlError as URLError where urlError.code == .notConnectedToInternet {
            throw Error.notConnectedToInternet
        } catch let urlError as URLError where urlError.code == .timedOut {
            guard isPrivateIpAddress(url.host() ?? "") else {
                throw Error.urlError(urlError)
            }
            throw Error.timeoutOnPrivateIp(urlError)
        } catch let urlError as URLError {
            throw Error.urlError(urlError)
        } catch let localizedError as LocalizedError {
            throw Error.localizedError(localizedError)
        } catch let nsError as NSError {
            throw Error.nsError(nsError)
        } catch {
            leaveBreadcrumb(.fatal, category: "api", message: "Unhandled error type", data: ["error": error])

            throw Error(from: error)
        }

        guard let data = json else {
            throw Error(from: AppError("Failed to unwrap JSON payload."))
        }

        let httpResponse: HTTPURLResponse? = response as? HTTPURLResponse
        let statusCode: Int = httpResponse?.statusCode ?? 599

        // leaveBreadcrumb(.debug, category: "api", message: "Response headers (\(statusCode))", data: parseResponseHeaders(httpResponse))

        switch statusCode {
        case (200..<400):
            if Response.self == Empty.self {
                return try decoder.decode(Response.self, from: Data("{}".utf8))
            }

            do {
                return try decoder.decode(Response.self, from: data)
            } catch let decodingError as DecodingError {
                leaveAttachment(url, data)
                leaveBreadcrumb(.fatal, category: "api", message: decodingError.context.debugDescription, data: ["error": decodingError])

                throw Error.decodingError(decodingError)
            } catch {
                throw Error(from: error)
            }
        default:
            if data.isEmpty {
                leaveBreadcrumb(.warning, category: "api", message: "Request failed", data: ["status": statusCode])

                throw Error.badStatusCode(code: statusCode)
            }

            if let payload = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let message = payload["message"] as? String
            {
                leaveBreadcrumb(.warning, category: "api", message: "Request failed", data: ["status": statusCode, "message": message])

                throw Error.errorResponse(code: statusCode, message: message)
            }

            if let payload = String(data: data, encoding: .utf8) {
                leaveBreadcrumb(.warning, category: "api", message: "Request failed", data: ["status": statusCode, "response": payload])
            } else {
                leaveBreadcrumb(.error, category: "api", message: "Unhandled request failure", data: ["status": statusCode])
            }

            throw Error.badStatusCode(code: statusCode)
        }
    }
    // swiftlint:enable cyclomatic_complexity function_body_length

    fileprivate static func request<Response: Decodable>(
        method: HTTPMethod = .get,
        url: URL,
        headers: [String: String] = [:],
        timeout: Double = 10,
        decoder: JSONDecoder = .init(),
        encoder: JSONEncoder = .init(),
        session: URLSession = .shared
    ) async throws -> Response {
        try await request(method: method, url: url, headers: headers, body: Empty?.none, timeout: timeout, decoder: decoder, encoder: encoder, session: session)
    }

    fileprivate static func parseResponseHeaders(_ response: HTTPURLResponse?) -> [String: Any] {
        guard let headerFields = response?.allHeaderFields else { return [:] }
        return Dictionary(uniqueKeysWithValues: headerFields.compactMap { ($0 as? (String, Any)) })
    }
}

enum HTTPMethod: String {
    case get
    case put
    case delete
    case post
}
// swiftlint:enable file_length
