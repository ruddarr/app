import Foundation

extension FailedRequest.Reason {
    init(_ error: API.Error) {
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
