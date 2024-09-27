import Sentry

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

    // TestFlight: report higher level breadcrumbs as events
    if Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" {
        if ![.error, .fatal].contains(level) {
            return
        }

        if data["error"] is API.Error || data["error"] is URLError {
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

enum EnvironmentType: String {
    case preview
    case simulator
    case debug
    case testflight
    case appstore
}

func isRunningIn(_ env: EnvironmentType) -> Bool {
    runningIn() == env
}

func runningIn() -> EnvironmentType {
    if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
        return EnvironmentType.preview
    }

#if targetEnvironment(simulator)
    return EnvironmentType.simulator
#elseif DEBUG
    return EnvironmentType.debug
#else
    if Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" {
        return EnvironmentType.testflight
    }

    return EnvironmentType.appstore
#endif
}
