import Foundation
import SwiftUI

struct API {
    var fetchMovies: (Instance) async throws -> [Movie]
    var lookupMovies: (_ instance: Instance, _ query: String) async throws -> [MovieLookup]
    var systemStatus: (Instance) async throws -> InstanceStatus
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
        }, systemStatus: { instance in
            let url = URL(string: instance.url)!
                .appending(path: "/api/v3/system/status")

            return try await request(url: url, authorization: instance.apiKey)
        })
    }

    fileprivate static func request<Body: Encodable, Response: Decodable>(
        method: HTTPMethod = .get,
        url: URL, authorization: String?,
        body: Body? = nil,
        decoder: JSONDecoder = .init(),
        encoder: JSONEncoder = .init(),
        session: URLSession = .shared
    ) async throws -> Response {
        try NetworkMonitor.shared.checkReachability()

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue.uppercased()
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        print(url)

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
            return try decoder.decode(Response.self, from: json)
        default:
            throw statusCode.map(Error.failingResponse) ?? SimpleError.assertionFailure
        }
    }

    struct Empty: Encodable { }

    // convenience version with no Body
    fileprivate static func request<Response: Decodable>(
        method: HTTPMethod = .get,
        url: URL, authorization: String?,
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
