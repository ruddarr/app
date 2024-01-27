import os
import Foundation
import SwiftUI

struct API {
    var fetchMovies: (Instance) async throws -> [Movie]
    var lookupMovies: (_ instance: Instance, _ query: String) async throws -> [Movie]
    var addMovie: (Movie, Instance) async throws -> Movie
    var deleteMovie: (Movie, Instance) async throws -> Empty
    var systemStatus: (Instance) async throws -> InstanceStatus
    var rootFolders: (Instance) async throws -> [InstanceRootFolders]
    var qualityProfiles: (Instance) async throws -> [InstanceQualityProfile]
}

extension API {
    static var live: Self {
        .init(fetchMovies: { instance in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/movie")

            return try await request(url: url, authorization: instance.apiKey)
        }, lookupMovies: { instance, query in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/movie/lookup")
                .appending(queryItems: [.init(name: "term", value: query)])

            return try await request(url: url, authorization: instance.apiKey)
        }, addMovie: { movie, instance in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/movie")

            return try await request(method: .post, url: url, authorization: instance.apiKey, body: movie)
        }, deleteMovie: { movie, instance in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/movie")
                .appending(path: String(movie.movieId!))
                .appending(queryItems: [.init(name: "deleteFiles", value: "true")])

            return try await request(method: .delete, url: url, authorization: instance.apiKey)
        }, systemStatus: { instance in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/system/status")

            return try await request(url: url, authorization: instance.apiKey)
        }, rootFolders: { instance in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/rootfolder")

            return try await request(url: url, authorization: instance.apiKey)
        }, qualityProfiles: { instance in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/qualityprofile")

            return try await request(url: url, authorization: instance.apiKey)
        })
    }

    struct Empty: Encodable, Decodable { }

    fileprivate static func request<Body: Encodable, Response: Decodable>(
        method: HTTPMethod = .get,
        url: URL,
        authorization: String?,
        body: Body? = nil,
        decoder: JSONDecoder = .init(),
        encoder: JSONEncoder = .init(),
        session: URLSession = .shared
    ) async throws -> Response {
        let log: Logger = logger("api")

        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601

        try NetworkMonitor.shared.checkReachability()

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue.uppercased()
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let httpString = "\(method.rawValue.uppercased()) \(url)"
        log.debug("\(httpString, privacy: .public)")
        print(httpString)

        if let body {
            request.httpBody = try encoder.encode(body)
        }

        if let authorization {
            request.addValue("Bearer \(authorization)", forHTTPHeaderField: "Authorization")
        }

        let (json, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode

        switch statusCode {
        case (200..<400)?:
            if Response.self == Empty.self {
                return try decoder.decode(Response.self, from: "{}".data(using: .utf8)!)
            } else {
                return try decoder.decode(Response.self, from: json)
            }
        default:
            if let rawJson = String(data: json, encoding: .utf8) {
                log.error("Request failed (\(statusCode ?? 0)) \(rawJson)")
                print("Request failed (\(statusCode ?? 0)) \(rawJson)")
            }

            throw statusCode.map(Error.failingResponse) ?? AppError.assertionFailure
        }
    }

    fileprivate static func request<Response: Decodable>(
        method: HTTPMethod = .get,
        url: URL,
        authorization: String?,
        decoder: JSONDecoder = .init(),
        encoder: JSONEncoder = .init(),
        session: URLSession = .shared
    ) async throws -> Response {
        try await request(method: method, url: url, authorization: authorization, body: Empty?.none, decoder: decoder, encoder: encoder, session: session)
    }
}

extension API {
    enum Error: LocalizedError {
        case failingResponse(statusCode: Int)
    }
}

enum HTTPMethod: String {
    case get
    case put
    case delete
    case post
}
