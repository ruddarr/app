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

        return .init(String(
            localized: "Upgrade to \(type.rawValue) v\(number) or newer.",
            comment: "Placeholders are instance type (Radarr/Sonarr) and version number"
        ))
    }
}
