import Foundation

typealias InstanceFailure = (instance: Instance, error: any Error)

/// Performs requests against an instance, replacing failures with a short message that names the instance.
func requesting<T>(_ instance: Instance, _ operation: () async throws -> T) async throws -> T {
    do {
        return try await operation()
    } catch let error as CancellationError {
        throw error
    } catch {
        throw AppError(instanceErrorMessage(error, instance))
    }
}

/// A short, user-facing message for a request that failed on one or more instances.
func instanceErrorMessage(_ failures: [InstanceFailure]) -> String {
    if failures.count == 1, let failure = failures.first {
        return instanceErrorMessage(failure.error, failure.instance)
    }

    let labels = failures.map { instanceLabel($0.instance) }.formatted(.list(type: .and))

    return String(localized: "Requests to \(labels) failed.")
}

/// A short, user-facing message for a request that failed on an instance.
func instanceErrorMessage(_ error: any Error, _ instance: Instance) -> String {
    let label = instanceLabel(instance)

    guard let error = error as? API.Error else {
        return error.localizedDescription
    }

    return switch error {
    case .notConnectedToInternet:
        String(localized: "You're not connected to the internet.")
    case .urlError, .timeoutOnPrivateIp:
        String(localized: "Couldn't reach \(label).")
    case .badStatusCode(code: 401), .badStatusCode(code: 403),
         .errorResponse(code: 401, message: _), .errorResponse(code: 403, message: _):
        String(localized: "\(label) rejected the API key.")
    case .badStatusCode(let code):
        String(localized: "\(label) responded with an error (\(code)).")
    case .errorResponse(_, let message):
        "\(label): \(message)"
    case .invalidUrl:
        String(localized: "The URL of \(label) is invalid.")
    case .decodingError:
        String(localized: "\(label) returned an unexpected response.")
    case .appError(let error):
        error.errorDescription ?? String(localized: "Something went wrong with \(label).")
    case .void, .localizedError, .nsError, .error:
        String(localized: "Something went wrong with \(label).")
    }
}

private func instanceLabel(_ instance: Instance) -> String {
    instance.label.isEmpty ? instance.type.rawValue : instance.label
}
