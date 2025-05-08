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
    var deleteMovie: (Movie, Bool, Bool, Instance) async throws -> Empty
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
    var deleteSeries: (Series, Bool, Bool, Instance) async throws -> Empty

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
    var manualImport: (String, Instance) async throws -> [ImportItem]

    var fetchHistory: (Int?, Int, Int, Instance) async throws -> MediaHistory

    var fetchNotifications: (Instance) async throws -> [InstanceNotification]
    var createNotification: (InstanceNotification, Instance) async throws -> InstanceNotification
    var updateNotification: (InstanceNotification, Instance) async throws -> InstanceNotification
    var deleteNotification: (InstanceNotification, Instance) async throws -> Empty
}

extension API {
    struct Empty: Encodable, Decodable { }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    static func request<Body: Encodable, Response: Decodable>(
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
        } catch let localizedError as any LocalizedError {
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

    static func request<Response: Decodable>(
        method: HTTPMethod = .get,
        url: URL,
        headers: [String: String] = [:],
        timeout: Double = 10,
        decoder: JSONDecoder = .init(),
        encoder: JSONEncoder = .init(),
        session: URLSession = .shared
    ) async throws -> Response {
        try await request(
            method: method,
            url: url,
            headers: headers,
            body: Empty?.none,
            timeout: timeout,
            decoder: decoder,
            encoder: encoder,
            session: session
        )
    }

    private static func parseResponseHeaders(_ response: HTTPURLResponse?) -> [String: Any] {
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
