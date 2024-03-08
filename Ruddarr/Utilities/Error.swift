import Foundation

struct AppError: LocalizedError {
    var errorDescription: String?
}

extension AppError {
    init(_ errorDescription: String) {
        self.init(errorDescription: errorDescription)
    }
}

extension AppError {
    static var assertionFailure: Self {
        Swift.assertionFailure()

        return .init(String(localized: "An unexpected error occurred."))
    }
}

extension URLError {
    static var timedOutOnPrivateIp: URLError {
        URLError(.timedOut, userInfo: [
            NSLocalizedDescriptionKey: URLError(.timedOut).localizedDescription,
            NSLocalizedRecoverySuggestionErrorKey: String(
                localized: "Are you attempting to connect to a private IP address from outside its network?"
            ),
        ])
    }
}
