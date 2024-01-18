import Foundation

enum HttpMethod: String {
    case get
    case put
    case delete
    case post
}

enum ApiError: Error {
    case noInternet
    case jsonFailure
    case requestFailure(_ error: Error)
    case badStatusCode(_ code: Int)
}

class Api<Model: Codable> {
    static func call(
        method: HttpMethod = .get,
        url: URL,
        authorization: String?,
        parameters: Encodable? = nil,
        completion: @escaping (Model) -> Void,
        failure: @escaping (ApiError) -> Void
    ) async {
        if !NetworkMonitor.shared.isReachable {
            return failure(.noInternet)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue

        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        if let parameters = parameters {
            request.httpBody = try? JSONEncoder().encode(parameters)
        }

        if authorization != nil {
            request.addValue("Bearer \(authorization!)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (json, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 599

            if statusCode >= 300 {
                failure(.badStatusCode(statusCode))
            }

            do {
                let data = try JSONDecoder().decode(Model.self, from: json)
                completion(data)
            } catch {
                failure(.jsonFailure)
            }
        } catch let error {
            failure(.requestFailure(error))
        }
    }
}
