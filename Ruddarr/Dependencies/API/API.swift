import Sentry

struct API: Sendable {
    var radarr: RadarrAPI
    var sonarr: SonarrAPI
    var chaptarr: ChaptarrAPI
    var instance: InstanceAPI
}

/// Endpoints only Radarr serves, or that only make sense against a Radarr instance.
struct RadarrAPI: Sendable {
    var fetch: @Sendable (Instance) async throws -> [Movie]
    var lookup: @Sendable (_ instance: Instance, _ query: String) async throws -> [Movie]
    var releases: @Sendable (Movie.ID, Instance) async throws -> [MovieRelease]

    var movie: @Sendable (Movie.ID, Instance) async throws -> Movie
    var history: @Sendable (Movie.ID, Instance) async throws -> [MediaHistoryEvent]
    var files: @Sendable (Movie.ID, Instance) async throws -> [MediaFile]
    var extraFiles: @Sendable (Movie.ID, Instance) async throws -> [MovieExtraFile]
    var add: @Sendable (Movie, Instance) async throws -> Movie
    var update: @Sendable (Movie, Bool, Instance) async throws -> API.Empty
    var delete: @Sendable (Movie, Bool, Bool, Instance) async throws -> API.Empty
    var deleteFile: @Sendable (MediaFile, Instance) async throws -> API.Empty

    var calendar: @Sendable (Date, Date, Instance) async throws -> [Movie]
}

/// Endpoints only Sonarr serves, or that only make sense against a Sonarr instance.
struct SonarrAPI: Sendable {
    var fetch: @Sendable (Instance) async throws -> [Series]
    var episodes: @Sendable (Series.ID, Instance) async throws -> [Episode]
    var lookup: @Sendable (_ instance: Instance, _ query: String) async throws -> [Series]
    var releases: @Sendable (Series.ID?, Series.ID?, Episode.ID?, Instance) async throws -> [SeriesRelease]

    var series: @Sendable (Series.ID, Instance) async throws -> Series
    var add: @Sendable (Series, Instance) async throws -> Series
    var push: @Sendable (Series, Instance) async throws -> Series
    var update: @Sendable (Series, Bool, Instance) async throws -> API.Empty
    var delete: @Sendable (Series, Bool, Bool, Instance) async throws -> API.Empty

    var monitorEpisode: @Sendable ([Episode.ID], Bool, Instance) async throws -> API.Empty
    var episodeHistory: @Sendable (Episode.ID, Instance) async throws -> MediaHistory
    var deleteEpisodeFile: @Sendable (MediaFile, Instance) async throws -> API.Empty
    var deleteEpisodeFiles: @Sendable ([MediaFile], Instance) async throws -> API.Empty

    var calendar: @Sendable (Date, Date, Instance) async throws -> [Episode]
}

/// Endpoints both Radarr and Sonarr serve identically, callable with any `Instance`.
///
/// `command` and `downloadRelease` share a route across both apps and discriminate
/// on their payload (see `InstanceCommand.payload` and `DownloadReleaseCommand`).
/// Endpoints only Chaptarr serves, or that only make sense against a Chaptarr instance.
struct ChaptarrAPI: Sendable {
    var fetch: @Sendable (Instance) async throws -> [Book]
    var page: @Sendable (_ instance: Instance, _ query: BookQuery, _ offset: Int, _ pageSize: Int) async throws -> BooksPage
    var search: @Sendable (_ instance: Instance, _ term: String) async throws -> [Book]
    var lookup: @Sendable (_ instance: Instance, _ query: String) async throws -> [Book]

    var book: @Sendable (Book.ID, Instance) async throws -> Book
    var series: @Sendable (Int, Instance) async throws -> [BookSeries]
    var files: @Sendable (Book.ID, Instance) async throws -> [BookFile]
    var history: @Sendable (Int, Book.ID, Instance) async throws -> [MediaHistoryEvent]
    var add: @Sendable (Book, Instance) async throws -> Book
    var monitor: @Sendable ([Book.ID], Bool, Instance) async throws -> API.Empty
    var deleteFile: @Sendable (BookFile, Instance) async throws -> API.Empty

    var calendar: @Sendable (Date, Date, Instance) async throws -> [Book]
}

struct InstanceAPI: Sendable {
    var command: @Sendable (InstanceCommand, Instance) async throws -> API.Empty
    var downloadRelease: @Sendable (DownloadReleaseCommand, Instance) async throws -> API.Empty

    var status: @Sendable (Instance) async throws -> InstanceStatus
    var rootFolders: @Sendable (Instance) async throws -> [InstanceRootFolder]
    var qualityProfiles: @Sendable (Instance) async throws -> [InstanceQualityProfile]
    var metadataProfiles: @Sendable (Instance) async throws -> [InstanceMetadataProfile]
    var diskSpace: @Sendable (Instance) async throws -> [InstanceDiskSpace]
    var tags: @Sendable (Instance) async throws -> [Tag]

    var queue: @Sendable (Instance) async throws -> QueueItems
    var deleteQueueTask: @Sendable (QueueItem.ID, Bool, Bool, Bool, Instance) async throws -> API.Empty

    var importableFiles: @Sendable (String, Instance) async throws -> [ImportableFile]

    var history: @Sendable (Int?, Int, Int, Instance) async throws -> MediaHistory

    var notifications: @Sendable (Instance) async throws -> [InstanceNotification]
    var createNotification: @Sendable (InstanceNotification, Instance) async throws -> InstanceNotification
    var updateNotification: @Sendable (InstanceNotification, Instance) async throws -> InstanceNotification
    var deleteNotification: @Sendable (InstanceNotification, Instance) async throws -> API.Empty
}

extension API {
    struct Empty: Encodable, Decodable { }

    static func request<Body: Encodable, Response: Decodable>(
        method: HTTPMethod = .get,
        url: URL,
        headers: [String: String] = [:],
        body: Body? = nil,
        instance: Instance? = nil,
        timeout: RequestTimeout = .default,
        decoder: JSONDecoder = .init(),
        encoder: JSONEncoder = .init(),
        session: URLSession = .shared,
        allowFailover: Bool = true
    ) async throws -> Response {
        let metrics = RequestMetricsCollector()

        do {
            return try await RequestMetricsCollector.$current.withValue(metrics) {
                try await send(
                    method: method, url: url, headers: headers, body: body, instance: instance,
                    timeout: timeout, decoder: decoder, encoder: encoder, session: session,
                    allowFailover: allowFailover
                )
            }
        } catch let error as CancellationError {
            throw error
        } catch API.Error.notConnectedToInternet {
            throw API.Error.notConnectedToInternet
        } catch {
            let key = await diagnosticsKey(of: instance)

            await RequestDiagnostics.shared.record(
                method: method.rawValue.uppercased(),
                url: (metrics.attemptedURL ?? url).absoluteString,
                instance: key,
                reason: FailedRequest.Reason((error as? API.Error) ?? API.Error(from: error)),
                transport: metrics.summary
            )

            throw error
        }
    }

    @MainActor
    private static func diagnosticsKey(of instance: Instance?) -> String? {
        guard let instance, AppSettings.shared.configuredInstances.contains(where: { $0.id == instance.id }) else {
            return nil
        }

        return instance.contextKey
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private static func send<Body: Encodable, Response: Decodable>(
        method: HTTPMethod = .get,
        url: URL,
        headers: [String: String] = [:],
        body: Body? = nil,
        instance: Instance? = nil,
        timeout: RequestTimeout = .default,
        decoder: JSONDecoder = .init(),
        encoder: JSONEncoder = .init(),
        session: URLSession = .shared,
        allowFailover: Bool = true
    ) async throws -> Response {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601extended

        try await NetworkMonitor.shared.checkReachability()

        var request = URLRequest(url: url)
        request.timeoutInterval = Self.effectiveTimeout(for: url, method: method, timeout: timeout)
        request.httpMethod = method.rawValue.uppercased()
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body {
            request.httpBody = try encoder.encode(body)
        }

        var effectiveHeaders = instance?.auth ?? [:]
        effectiveHeaders.merge(headers) { _, explicit in explicit }

        for (key, value) in effectiveHeaders.sorted(by: { $0.key < $1.key }) {
            request.addValue(value, forHTTPHeaderField: key)
        }

        // leaveBreadcrumb(.debug, category: "api", message: "Sending request", data: [
        //     "url": url,
        //     "method": method.rawValue,
        //     "timeout": timeout,
        // ])

        if let body {
            leaveBreadcrumb(.debug, category: "api", message: "Request body", data: ["body": body])
        }

        var json: Data?
        var response: URLResponse?
        var attemptedURL = url
        let maxFailovers = (instance?.candidateURLs.count ?? 1) - 1
        var failovers = 0

        attempts: while true {
            do {
                (json, response) = try await Self.data(for: request, session: session, retryOnConnectionLost: method == .get)
                break attempts
            } catch let cancellationError as CancellationError {
                // re-throw `CancellationError` so they can be handled elsewhere
                throw cancellationError
            } catch let urlError as URLError where urlError.code == .cancelled {
                // re-throw `URLError.cancelled` as `CancellationError`
                throw CancellationError()
            } catch let urlError as URLError where urlError.code == .notConnectedToInternet {
                throw Error.notConnectedToInternet
            } catch let urlError as URLError {
                if allowFailover, failovers < maxFailovers, Self.canFailover(urlError.code, method: method), let instance,
                   let fallback = await InstanceResolver.shared.failover(afterFailing: attemptedURL, for: instance)
                {
                    leaveBreadcrumb(.info, category: "api", message: "Switching to next instance URL", data: ["code": urlError.code.rawValue])

                    failovers += 1
                    attemptedURL = fallback
                    RequestMetricsCollector.current?.noteAttempt(fallback)
                    request.url = fallback
                    request.timeoutInterval = Self.effectiveTimeout(for: fallback, method: method, timeout: timeout)

                    continue attempts
                }

                if urlError.code == .timedOut, isPrivateIpAddress(attemptedURL.host() ?? "") {
                    throw Error.timeoutOnPrivateIp(urlError)
                }

                throw Error.urlError(urlError)
            } catch let localizedError as any LocalizedError {
                throw Error.localizedError(localizedError)
            } catch let nsError as NSError {
                throw Error.nsError(nsError)
            } catch {
                leaveBreadcrumb(.fatal, category: "api", message: "Unhandled error type", data: ["error": error])

                throw Error(from: error)
            }
        }

        guard let data = json else {
            throw Error(from: AppError("Failed to unwrap JSON payload."))
        }

        let httpResponse: HTTPURLResponse? = response as? HTTPURLResponse
        let statusCode: Int = httpResponse?.statusCode ?? 599

        if let instance {
            await InstanceResolver.shared.noteSuccess(for: attemptedURL, instance: instance)
        }

        // print(String(data: data, encoding: .utf8) ?? "non-utf8 response")
        // leaveBreadcrumb(.debug, category: "api", message: "Response headers (\(statusCode))", data: parseResponseHeaders(httpResponse))

        switch statusCode {
        case (200..<400):
            if Response.self == Empty.self {
                return try decoder.decode(Response.self, from: Data("{}".utf8))
            }

            do {
                return try decoder.decode(Response.self, from: data)
            } catch let decodingError as DecodingError {
                leaveBreadcrumb(.warning, category: "api", message: decodingError.context.debugDescription, data: ["error": decodingError])

                if !decodingError.isUnexpectedResponseShape {
                    reportDecodingFailure(decodingError, url: attemptedURL, body: data)
                }

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
        instance: Instance? = nil,
        timeout: RequestTimeout = .default,
        decoder: JSONDecoder = .init(),
        encoder: JSONEncoder = .init(),
        session: URLSession = .shared,
        allowFailover: Bool = true
    ) async throws -> Response {
        try await request(
            method: method, url: url, headers: headers, body: Empty?.none, instance: instance,
            timeout: timeout, decoder: decoder, encoder: encoder, session: session, allowFailover: allowFailover
        )
    }

    static func request<Body: Encodable, Response: Decodable>(
        method: HTTPMethod = .get,
        url: URL,
        headers: [String: String] = [:],
        body: Body? = nil,
        instance: Instance? = nil,
        timeout: InstanceTimeout,
        decoder: JSONDecoder = .init(),
        encoder: JSONEncoder = .init(),
        session: URLSession = .shared
    ) async throws -> Response {
        try await request(
            method: method, url: url, headers: headers, body: body, instance: instance,
            timeout: instance?.timeout(timeout) ?? .default, decoder: decoder, encoder: encoder, session: session
        )
    }

    static func request<Response: Decodable>(
        method: HTTPMethod = .get,
        url: URL,
        headers: [String: String] = [:],
        instance: Instance? = nil,
        timeout: InstanceTimeout,
        decoder: JSONDecoder = .init(),
        encoder: JSONEncoder = .init(),
        session: URLSession = .shared
    ) async throws -> Response {
        try await request(
            method: method, url: url, headers: headers, instance: instance,
            timeout: instance?.timeout(timeout) ?? .default, decoder: decoder, encoder: encoder, session: session
        )
    }

    private static func effectiveTimeout(for url: URL, method: HTTPMethod, timeout: RequestTimeout) -> Double {
        guard method == .get, timeout.local != timeout.remote, let host = url.host() else { return timeout.remote }
        return timeout.interval(isLocal: NetworkInterfaces.role(forHost: host) == .lan)
    }

    private static func data(for request: URLRequest, session: URLSession, retryOnConnectionLost: Bool) async throws -> (Data, URLResponse) {
        let metrics = RequestMetricsCollector.current

        do {
            metrics?.beginAttempt()

            return try await session.data(for: request, delegate: metrics)
        } catch let urlError as URLError where retryOnConnectionLost && urlError.code == .networkConnectionLost {
            metrics?.beginAttempt()

            return try await session.data(for: request, delegate: metrics)
        }
    }

    private static func canFailover(_ code: URLError.Code, method: HTTPMethod) -> Bool {
        switch code {
        case .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
            return true
        case .timedOut, .networkConnectionLost:
            return method == .get
        default:
            return false
        }
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
