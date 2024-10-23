import Sentry
import StoreKit

func leaveAttachment(_ url: URL, _ json: Data) {
    let basename = url.relativePath.replacingOccurrences(of: "/", with: "-")
    let timestamp = Date().timeIntervalSince1970

    let attachment = Attachment(
        data: json,
        filename: "\(basename)-\(timestamp).json",
        contentType: "application/json"
    )

    SentrySDK.configureScope { scope in
        scope.addAttachment(attachment)
    }
}

// swiftlint:disable cyclomatic_complexity
func leaveBreadcrumb(
    _ level: SentryLevel,
    category: String,
    message: String?,
    data: [String: Any] = [:]
) {
    let crumb = Breadcrumb(
        level: level,
        category: category
    )

    crumb.message = message
    crumb.data = data

    SentrySDK.addBreadcrumb(crumb)

    if isRunningIn(.testflight) {
        // report only `.error` and `.fatal` breadcrumbs as events
        if ![.error, .fatal].contains(level) {
            return
        }

        if data["error"] is API.Error || data["error"] is URLError {
            return
        }

        if message?.range(
            of: "HTTP Client Error with status code: 50\\d",
            options: .regularExpression
        ) != nil {
            return
        }

        let event = Event(level: level)
        event.message = SentryMessage(formatted: message ?? "")

        SentrySDK.capture(event: event)
    }

#if DEBUG
    let dataString: String = data
        .sorted { $0.key > $1.key }
        .map { key, value in "\(key): \(value)" }
        .joined(separator: "; ")

    let levelString: String = switch level {
    case .debug: "debug"
    case .info: "info"
    case .warning: "warning"
    case .error: "error"
    case .fatal: "fatal"
    case .none: "none"
    @unknown default: "@unknown"
    }

    print("[\(levelString)] #\(category): \(message ?? "") (\(dataString))")
#endif
}
// swiftlint:enable cyclomatic_complexity

enum EnvironmentType: String {
    case preview
    case simulator
    case debug
    case testflight
    case appstore

    static var cache: EnvironmentType?
}

func isRunningIn(_ env: EnvironmentType) -> Bool {
    runningIn() == env
}

func runningIn() -> EnvironmentType {
    if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
        return .preview
    }

#if targetEnvironment(simulator)
    return .simulator
#elseif DEBUG
    return .debug
#else
    if let env = EnvironmentType.cache {
        return env
    }

    let semaphore = DispatchSemaphore(value: 0)
    var isTestFlight = false

    Task {
        let shared = try? await AppTransaction.shared

        switch shared {
        case .verified(let transaction):
            isTestFlight = transaction.environment == .sandbox
        case .unverified, .none: break
        }

        semaphore.signal()
    }

    semaphore.wait()

    EnvironmentType.cache = isTestFlight ? .testflight : .appstore

    return isTestFlight ? .testflight : .appstore
#endif
}
