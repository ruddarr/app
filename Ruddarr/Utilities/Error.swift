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

    static func upgradeRequired(_ type: InstanceType, to version: String) -> Self {
        let number = String(version.trimmingPrefix("v"))
        let target = "\(type.rawValue) v\(number)"

        return .init(String(
            localized: "Upgrade to \(target) or newer.",
            comment: "Placeholder is the instance type and minimum version (e.g. Sonarr v4.0.5)"
        ))
    }
}
