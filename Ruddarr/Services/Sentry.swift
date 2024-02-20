import Sentry

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

    // report higher level breadcrumbs as events in TestFlight
    if Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" {
        if level == .error || level == .error {
            let event = Event(level: level)
            event.message = SentryMessage(formatted: message ?? "")

            SentrySDK.capture(event: event)
        }
    }

#if DEBUG
    let dataString: String = data.map { key, value in
        "\(key): \(value)"
    }.joined(separator: "; ")

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

func environmentName() -> String {
    if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
        return "preview"
    }

    #if targetEnvironment(simulator)
        return "simulator"
    #elseif DEBUG
        return "debug"
    #else
        if Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" {
            return "testflight"
        }

        return "appstore"
    #endif
}
