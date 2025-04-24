import Sentry
import CloudKit
import StoreKit

func setSentryCloudKitContext() async {
    guard dependencies.cloudkit == .live else { return }

    let container = CKContainer.default()
    let accountStatus = try? await container.accountStatus()
    let cloudKitUserId = try? await container.userRecordID()

    setSentryContext(for: "cloudkit", [
        "status": cloudKitStatusString(accountStatus),
        "identifier": cloudKitUserId?.recordName ?? "",
    ])
}

func setSentryContext(for key: String, _ value: [String: Any]) {
    SentrySDK.configureScope { scope in
        scope.setContext(value: value, key: key)
    }
}

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

    if isRunningIn(.testflight) && shouldReportEvent(crumb) {
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

func shouldReportEvent( _ crumb: Breadcrumb) -> Bool {
    // report only `.error` and `.fatal` breadcrumbs as events
    if ![.error, .fatal].contains(crumb.level) {
        return false
    }

    if crumb.data?["error"] is URLError {
        return false
    }

    if crumb.data?["error"] is API.Error {
        return false
    }

    // usually an authorization issue, not relevant
    if crumb.message?.contains("data was not valid JSON") == true {
        return false
    }

    return true
}

enum EnvironmentType: String {
    case preview
    case simulator
    case debug
    case testflight
    case appstore

    nonisolated(unsafe) static var cache: EnvironmentType?
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

    guard let branch = Bundle.main.object(forInfoDictionaryKey: "CI_BRANCH") as? String else {
        EnvironmentType.cache = .appstore
        return .appstore
    }

    let isTestFlight = branch.contains("develop")

    EnvironmentType.cache = isTestFlight ? .testflight : .appstore

    return isTestFlight ? .testflight : .appstore
#endif
}
