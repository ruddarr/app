import Foundation
import SwiftUI

enum APIError: Error {
    case noInternet
    case jsonFailure(_ error: Error)
    case requestFailure(_ error: Error)
    case badStatusCode(_ code: Int)
}

struct API {
    var fetchMovies: (Instance) async throws -> [Movie]
    var lookupMovies: (_ instance: Instance, _ query: String) async throws -> [MovieLookup]
    //TODO: validation actualy modifies the instance, this doesn't feel right but I kept the same semantics as we've had previously.
    var fetchInstanceStatus: (inout Instance) async throws -> InstanceStatus
}

extension API {
    static var live: Self {
        .init(fetchMovies: { instance in
            let url = URL(string: instance.url)!.appending(path: "/api/v3/movie")
            return try await request(url: url, authorization: instance.apiKey)
        }, lookupMovies: { instance, query in
            let url = URL(string: instance.url)!.appending(path: "/api/v3/movie/lookup").appending(queryItems: [.init(name: "term", value: query)])
            return try await request(url: url, authorization: instance.apiKey)
        }, fetchInstanceStatus: { instance in
            let rawUrl = URL(string: instance.url)!

            // strip path from URL
            var components = URLComponents(url: rawUrl, resolvingAgainstBaseURL: false)!
            components.path = ""

            let url = components.url!
            instance.url = url.absoluteString

            if await !UIApplication.shared.canOpenURL(url) {
                throw ValidationError.urlNotValid
            }

            let statusUrl = URL(string: "\(url)/api/v3/system/status")!
            return try await request(url: statusUrl, authorization: instance.apiKey)
            
        })
    }
    
    fileprivate static func request<Body: Encodable, Response: Decodable>(method: HTTPMethod = .get, url: URL, authorization: String?, body: Body? = nil, decoder: JSONDecoder = .init(), encoder : JSONEncoder = .init(), session: URLSession = .shared) async throws -> Response {
        if !NetworkMonitor.shared.isReachable {
            throw APIError.noInternet
        }
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue.uppercased()
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body {
            request.httpBody = try encoder.encode(body)
        }

        if let authorization {
            request.addValue("Bearer \(authorization)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (json, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 599

            if statusCode >= 300 {
                throw APIError.badStatusCode(statusCode)
            }

            do {
                return try decoder.decode(Response.self, from: json)
            } catch let error {
                throw APIError.jsonFailure(error)
            }
        } catch let apiError as APIError {
            //TODO: personally I'd just stick to idiomatic Swift's untyped errors as they have better ergonomics built in to the language. But if this is important to you, we can keep using strongly typed errors. In that case, we might consider replacing the `throws` keyword with Swift's Result type as the return value. I went with idiomatic Swift for my function api until told otherwise.
            throw apiError //don't rewrap in `.requestFailure`
        }
        catch let error {
            throw APIError.requestFailure(error)
        }
    }
    
    struct Empty: Encodable { }
    // convenience version with no Body
    fileprivate static func request<Response: Decodable>(method: HTTPMethod = .get, url: URL, authorization: String?, decoder: JSONDecoder = .init(), encoder : JSONEncoder = .init(), session: URLSession = .shared) async throws -> Response {
        try await request(method: method, url: url, authorization: authorization, body: Empty?.none, decoder: decoder, encoder: encoder, session: session)
    }
}

enum HTTPMethod: String {
    case get
    case put
    case delete
    case post
}






