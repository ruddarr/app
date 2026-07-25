import Foundation

extension LocalizedError {
    var recoverySuggestionFallback: String {
        recoverySuggestion ?? String(localized: "Try again later.")
    }
}

extension API {
    enum Error: Swift.Error {
        case void

        case invalidUrl(_ url: String)
        case badStatusCode(code: Int)
        case decodingError(_ error: DecodingError)
        case errorResponse(code: Int, message: String)
        case notConnectedToInternet
        case timeoutOnPrivateIp(_ error: URLError)

        case appError(_ error: AppError)
        case localizedError(_ error: any LocalizedError)
        case urlError(_ error: URLError)
        case nsError(_ error: NSError)
        case error(_ error: any Swift.Error)

        init(_ value: Error) {
            self = value
        }

        init(from error: any Swift.Error) {
            if let appError = error as? AppError {
                self = .appError(appError)
            } else {
                self = .error(error)
            }
        }
    }
}

extension API.Error: LocalizedError {
    var errorDescription: String? {
        let fallback = String(localized: "Something Went Wrong")

        return switch self {
        case .void:
            fallback
        case .invalidUrl:
            String(localized: "Invalid URL")
        case .badStatusCode:
            String(localized: "Server Error Response")
        case .errorResponse:
            String(localized: "Server Error Response")
        case .notConnectedToInternet:
            NoInternet.Title
        case .timeoutOnPrivateIp:
            String(localized: "URL Not Reachable")
        case .decodingError:
            String(localized: "Response Decoding Error")
        case .appError:
            fallback
        case .localizedError(let error):
            error.errorDescription ?? fallback
        case .urlError:
            String(localized: "URL Not Reachable")
        case .nsError:
            fallback
        case .error:
            fallback
        }
    }

    var recoverySuggestion: String? {
        let fallback = String(localized: "Try again later.")

        return switch self {
        case .void:
            fallback
        case .invalidUrl(let url):
            String(localized: "Instance URL is not valid: \(url)")
        case .badStatusCode(code: let code):
            String(localized: "Server returned \(code) status code.")
        case .decodingError(let error):
            "[%@] %@".placeholders(
                error.context.codingPath.map(\.stringValue).joined(separator: ", "),
                error.context.debugDescription
            )
        case .errorResponse(code: let code, message: let message):
            "[\(code)] \(message)"
        case .notConnectedToInternet:
            NoInternet.Description
        case .timeoutOnPrivateIp(let error):
            "\(error.localizedDescription)\n\n" + String(
                localized: "Are you attempting to connect to a private IP address from outside its network?"
            )
        case .appError(let error):
            error.errorDescription ?? fallback
        case .localizedError(let error):
            error.recoverySuggestion ?? error.failureReason ?? fallback
        case .urlError(let error):
            error.localizedDescription
        case .nsError(let error):
            error.localizedDescription
        case .error(let error):
            String(localized: "An unknown error occurred: %@").placeholders("\(error)")
        }
    }
}

extension DecodingError {
    var context: DecodingError.Context {
        switch self {
        case .dataCorrupted(let context): context
        case .keyNotFound(_, let context): context
        case .typeMismatch(_, let context): context
        case .valueNotFound(_, let context): context
        @unknown default:
            DecodingError.Context(codingPath: [], debugDescription: "Unhandled decoding error occurred")
        }
    }
}

extension FailedRequest.Reason {
    init(_ error: API.Error) { // swiftlint:disable:this cyclomatic_complexity
        switch error {
        case .badStatusCode(let code):
            self = .status(code: code, message: nil)
        case .errorResponse(let code, let message):
            self = .status(code: code, message: message)
        case .decodingError(let error):
            let path = error.context.codingPath.map(\.stringValue).joined(separator: ".")
            let description = error.context.debugDescription
            self = .decoding(path.isEmpty ? description : "\(path): \(description)")
        case .notConnectedToInternet:
            self = .transport("Not connected to the internet")
        case .timeoutOnPrivateIp(let error):
            self = .transport(error.localizedDescription)
        case .urlError(let error):
            self = .transport(error.localizedDescription)
        case .nsError(let error):
            self = .transport(error.localizedDescription)
        case .localizedError(let error):
            self = .transport(error.errorDescription ?? String(describing: error))
        case .appError(let error):
            self = .transport(error.errorDescription ?? String(describing: error))
        case .invalidUrl(let url):
            self = .transport("Invalid URL: \(url)")
        case .error(let error):
            self = .transport(String(describing: error))
        case .void:
            self = .transport("Request failed")
        }
    }
}
