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

        return .init("An unexpected error occurred")
    }
}
