import Foundation

enum InstanceError: Error {
    case urlIsLocal
    case urlNotValid
    case urlNotReachable(_ error: Error)
    case badAppName(_ name: String)
    case badStatusCode(_ code: Int)
    case badResponse(_ error: Error)
    case errorResponse(_ code: Int, _ message: String)
    case timedOutOnPrivateIp(_ error: URLError)
}

extension InstanceError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .urlIsLocal, .urlNotValid:
            return String(localized: "Invalid URL")
        case .urlNotReachable, .timedOutOnPrivateIp:
            return String(localized: "URL Not Reachable")
        case .badAppName:
            return String(localized: "Wrong Instance Type")
        case .badStatusCode:
            return String(localized: "Invalid Status Code")
        case .badResponse:
            return String(localized: "Invalid Server Response")
        case .errorResponse:
            return String(localized: "Server Error Response")
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .urlIsLocal:
            return String(localized: "URLs must be non-local, \"localhost\" and \"127.0.0.1\" will not work.")
        case .urlNotValid:
            return String(localized: "Enter a valid URL.")
        case .urlNotReachable(let error):
            return error.localizedDescription
        case .timedOutOnPrivateIp(let urlError):
            let nsError = urlError as NSError
            return "\(urlError.localizedDescription)\n\n\(nsError.localizedRecoverySuggestion ?? "")"
        case .badAppName(let name):
            return String(localized: "URL returned is a \(name) instance.")
        case .badStatusCode(let code):
            return String(localized: "URL returned \(code) status code.")
        case .badResponse(let error):
            return error.localizedDescription
        case .errorResponse(let code, let message):
            return "[\(code)] \(message)"
        }
    }
}
