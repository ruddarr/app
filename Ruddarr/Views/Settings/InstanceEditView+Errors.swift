import SwiftUI

enum InstanceError: Error {
    case urlIsLocal
    case urlNotValid
    case urlSchemeMissing

    case alternateUrlIsLocal
    case alternateUrlNotValid
    case alternateUrlSchemeMissing
    case alternateSameAsUrl

    case localNetworkDenied
    case badAppName(_ reported: String, _ expected: String)
    case apiError(_ error: API.Error)
}

extension InstanceError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .urlIsLocal, .urlNotValid, .urlSchemeMissing:
            String(localized: "Invalid URL")
        case .alternateUrlIsLocal, .alternateUrlNotValid, .alternateSameAsUrl, .alternateUrlSchemeMissing:
            String(localized: "Invalid Alternate URL")
        case .localNetworkDenied:
            String(localized: "Local Network Access Denied")
        case .badAppName:
            String(localized: "Wrong Instance Type")
        case .apiError(let error):
            error.errorDescription
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .urlIsLocal, .alternateUrlIsLocal:
            String(localized: "URLs must be non-local, \"localhost\" and \"127.0.0.1\" will not work.")
        case .urlNotValid, .alternateUrlNotValid:
            String(localized: "Enter a valid URL.")
        case .urlSchemeMissing, .alternateUrlSchemeMissing:
            String(localized: "URL must start with \"http://\" or \"https://\".")
        case .alternateSameAsUrl:
            String(localized: "The Alternate URL must be different from the primary URL.")
        case .localNetworkDenied:
            String(localized: "Local network access must be granted in System Settings to connect to instances on private IP addresses.")
        case .badAppName(let reported, let expected):
            String(localized: "URL identified itself as a \(reported) instance, not a \(expected) instance.")
        case .apiError(let error):
            error.recoverySuggestion
        }
    }
}
