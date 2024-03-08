import os
import SwiftUI

struct API {
    var fetchMovies: (Instance) async throws -> [Movie]
    var lookupMovies: (_ instance: Instance, _ query: String) async throws -> [Movie]
    var lookupReleases: (Movie.ID, Instance) async throws -> [MovieRelease]
    var downloadRelease: (String, Int, Instance) async throws -> Empty

    var getMovie: (Movie.ID, Instance) async throws -> Movie
    var addMovie: (Movie, Instance) async throws -> Movie
    var updateMovie: (Movie, Bool, Instance) async throws -> Empty
    var deleteMovie: (Movie, Instance) async throws -> Empty

    var command: (RadarrCommand, Instance) async throws -> Empty
    var systemStatus: (Instance) async throws -> InstanceStatus
    var rootFolders: (Instance) async throws -> [InstanceRootFolders]
    var qualityProfiles: (Instance) async throws -> [InstanceQualityProfile]

    var fetchNotifications: (Instance) async throws -> [InstanceNotification]
    var createNotification: (InstanceNotification, Instance) async throws -> InstanceNotification
    var updateNotification: (InstanceNotification, Instance) async throws -> InstanceNotification
    var deleteNotification: (InstanceNotification, Instance) async throws -> Empty
}

extension API {
    static var live: Self {
        .init(fetchMovies: { instance in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/movie")

            return try await request(url: url, headers: instance.auth)
        }, lookupMovies: { instance, query in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/movie/lookup")
                .appending(queryItems: [.init(name: "term", value: query)])

            return try await request(url: url, headers: instance.auth)
        }, lookupReleases: { movieId, instance in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/release")
                .appending(queryItems: [.init(name: "movieId", value: String(movieId))])

            return try await request(url: url, headers: instance.auth, timeout: 60)
        }, downloadRelease: { guid, indexerId, instance in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/release")

            let body = DownloadMovieRelease(guid: guid, indexerId: indexerId)

            return try await request(method: .post, url: url, headers: instance.auth, body: body)
        }, getMovie: { movieId, instance in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/movie")
                .appending(path: String(movieId))

            return try await request(url: url, headers: instance.auth)
        }, addMovie: { movie, instance in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/movie")

            return try await request(method: .post, url: url, headers: instance.auth, body: movie)
        }, updateMovie: { movie, moveFiles, instance in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/movie/editor")

            let body = MovieEditorResource(
                movieIds: [movie.movieId!],
                monitored: movie.monitored,
                qualityProfileId: movie.qualityProfileId,
                minimumAvailability: movie.minimumAvailability,
                rootFolderPath: movie.rootFolderPath,
                moveFiles: moveFiles ? true : nil
            )

            return try await request(method: .put, url: url, headers: instance.auth, body: body)
        }, deleteMovie: { movie, instance in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/movie")
                .appending(path: String(movie.movieId!))
                .appending(queryItems: [.init(name: "deleteFiles", value: "true")])

            return try await request(method: .delete, url: url, headers: instance.auth)
        }, command: { command, instance in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/command")

            return try await request(method: .post, url: url, headers: instance.auth, body: command)
        }, systemStatus: { instance in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/system/status")

            return try await request(url: url, headers: instance.auth)
        }, rootFolders: { instance in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/rootfolder")

            return try await request(url: url, headers: instance.auth)
        }, qualityProfiles: { instance in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/qualityprofile")

            return try await request(url: url, headers: instance.auth)
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
                .appending(path: String(model.id))

            return try await request(method: .put, url: url, headers: instance.auth, body: model)
        }, deleteNotification: { model, instance in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/notification")
                .appending(path: String(model.id))

            return try await request(method: .delete, url: url, headers: instance.auth)
        })
    }

    struct Empty: Encodable, Decodable { }

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
        decoder.dateDecodingStrategy = .iso8601

        try NetworkMonitor.shared.checkReachability()

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
            "body": body ?? "",
        ])

        let (json, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 599

        switch statusCode {
        case (200..<400):
            let data = Response.self != Empty.self
                ? json
                : "{}".data(using: .utf8)!

            return try decoder.decode(Response.self, from: data)
        default:
            var message: String?

            do {
                if let data = try JSONSerialization.jsonObject(with: json, options: []) as? [String: Any] {
                    if let error = data["message"] as? String {
                        message = error
                    }
                }
            } catch {
                leaveBreadcrumb(.error, category: "api", message: "Failed to decode error response", data: ["status": statusCode, "error": error])

                if let data = String(data: json, encoding: .utf8) {
                    leaveBreadcrumb(.debug, category: "api", message: "Request failed", data: ["status": statusCode, "response": data])
                }
            }

            if let error = message {
                leaveBreadcrumb(.warning, category: "api", message: error, data: ["status": statusCode])

                throw Error.errorResponse(code: statusCode, message: error)
            }

            throw Error.badStatusCode(code: statusCode)
        }
    }

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
}

extension API {
    enum Error: LocalizedError {
        case badStatusCode(code: Int)
        case errorResponse(code: Int, message: String)
    }
}

extension API.Error {
    var errorDescription: String? {
        switch self {
        case .badStatusCode(let code):
            return String(localized: "Server returned \(code) status code.")
        case .errorResponse(let code, let message):
            return "[\(code)] \(message)"
        }
    }
}

enum HTTPMethod: String {
    case get
    case put
    case delete
    case post
}
