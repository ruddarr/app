import Sentry
import CloudKit
import StoreKit

@MainActor
func startSentry() {
    SentrySDK.start { options in
        options.enabled = true
        options.debug = false
        options.environment = runningIn().rawValue

        options.dsn = Secrets.SentryDsn
        options.sendDefaultPii = false

        options.swiftAsyncStacktraces = true

        options.enableSigtermReporting = true
        options.enableWatchdogTerminationTracking = true
        options.enableMetricKit = false
        options.enableAppHangTracking = isRunningIn(.testflight)
        options.appHangTimeoutInterval = 3
        #if os(iOS)
            options.enableReportNonFullyBlockingAppHangs = isRunningIn(.testflight)
        #endif
        options.enableCaptureFailedRequests = false
        options.enableTimeToFullDisplayTracing = false

        options.tracesSampleRate = 1
        options.tracePropagationTargets = []

        #if os(iOS)
            options.attachViewHierarchy = false
            options.enablePreWarmedAppStartTracing = true
            options.enablePersistingTracesWhenCrashing = true
        #endif

        options.beforeBreadcrumb = { crumb in
            guard shouldRecordBreadcrumb(crumb) else { return nil }
            return maskRequestURL(crumb)
        }

        options.beforeSend = { event in
            Bundle.main.bundleIdentifier == "com.ruddarr" ? event : nil
        }
    }

    setSentryContext(for: "device", ["identifier": Platform.deviceId])
}

func setSentryCloudKitContext() async {
    guard !isRunningIn(.preview) else { return }
    guard dependencies.cloudkit == .live else { return }

    let container = CKContainer.default()
    let accountStatus = try? await container.accountStatus()
    let cloudKitUserId = try? await container.userRecordID()

    setSentryContext(for: "CloudKit", [
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

    let shouldReport = isRunningIn(.testflight) && shouldReportEvent(crumb)

    crumb.message = message.map(maskURLs(in:))
    crumb.data = maskedBreadcrumbData(data)

    SentrySDK.addBreadcrumb(crumb)

    if shouldReport {
        let event = Event(level: level)
        event.message = SentryMessage(formatted: crumb.message ?? "")
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

private func shouldRecordBreadcrumb( _ crumb: Breadcrumb) -> Bool {
    // drop `GET /api/v3/queue` spam
    if crumb.category == "http" {
        let url = crumb.data?["url"] as? String
        let method = crumb.data?["method"] as? String

        if let url, url.contains(/\/api\/v\d\/queue$/), method == "GET" {
            return false
        }
    }

    return true
}

private func maskRequestURL( _ crumb: Breadcrumb) -> Breadcrumb {
    guard crumb.category == "http", let url = crumb.data?["url"] as? String else { return crumb }

    crumb.data?["url"] = maskedURL(url)

    return crumb
}

private func maskedBreadcrumbData(_ data: [String: Any]) -> [String: Any] {
    data.mapValues { value -> Any in
        if let string = value as? String {
            return maskURLs(in: string)
        }

        if let error = value as? any Swift.Error {
            return maskURLs(in: String(describing: error))
        }

        return value
    }
}

enum EnvironmentType: String {
    case preview
    case simulator
    case debug
    case testflight
    case appstore

    static let cached: EnvironmentType = {
        guard let branch = Bundle.main.object(forInfoDictionaryKey: "CI_BRANCH") as? String else {
            return .appstore
        }

        return branch.contains("develop") ? .testflight : .appstore
    }()
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
    return EnvironmentType.cached
#endif
}
