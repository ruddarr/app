import Foundation

struct SimpleError: LocalizedError {
    var errorDescription: String?
}

extension SimpleError {
    init(_ errorDescription: String) {
        self.init(errorDescription: errorDescription)
    }
}

extension SimpleError {
    static var assertionFailure: Self {
        Swift.assertionFailure()
        return .init("An unexpected error occured")
    }
}
