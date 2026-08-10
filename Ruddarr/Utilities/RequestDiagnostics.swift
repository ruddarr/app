import os
import Foundation

actor RequestDiagnostics {
    static let shared = RequestDiagnostics()

    private var entries: [FailedRequest] = []
    private let limit = 50

    func record(method: String, url: String, instance: String?, reason: FailedRequest.Reason, transport: String? = nil) {
        let instance = (instance?.isEmpty == false) ? instance : nil

        entries.removeAll {
            $0.method == method && $0.url == url && $0.instance == instance && $0.reason == reason
        }

        entries.insert(
            FailedRequest(
                id: UUID(),
                date: Date(),
                method: method,
                url: url,
                instance: instance,
                reason: reason,
                transport: transport
            ),
            at: 0
        )

        if entries.count > limit {
            entries.removeLast(entries.count - limit)
        }
    }

    func snapshot() -> [FailedRequest] {
        entries
    }

    func clear() {
        entries.removeAll()
    }

#if DEBUG
    func seed(_ entries: [FailedRequest]) {
        self.entries = entries
    }
#endif
}

struct FailedRequest: Identifiable, Equatable, Sendable {
    let id: UUID
    let date: Date
    let method: String
    let url: String
    let instance: String?
    let reason: Reason

    /// What the transport measured, e.g. `waiting for response • 2.51s of 2.50s`.
    var transport: String?

    enum Reason: Equatable, Sendable {
        case status(code: Int, message: String?)
        case decoding(String)
        case transport(String)
    }

    var badge: String {
        switch reason {
        case .status(let code, _): "\(code)"
        case .decoding: "Decode"
        case .transport: "Failed"
        }
    }

    var detail: String? {
        switch reason {
        case .status(_, let message): message
        case .decoding(let text): text
        case .transport(let text): text
        }
    }
}

/// Reads back how far a request got from `URLSessionTaskMetrics`: a timeout while connecting never
/// reached the server, a timeout while waiting means the server answered too slowly. `URLError`
/// alone cannot tell those apart. Metrics are not `Sendable`, so only the summary escapes.
final class RequestMetricsCollector: NSObject, URLSessionTaskDelegate, Sendable {
    /// Set for the duration of one `API.request`, so the transport can pick up the collector for
    /// the request it is running without every function in between passing it along.
    @TaskLocal static var current: RequestMetricsCollector?

    private let captured = OSAllocatedUnfairLock<String?>(initialState: nil)
    private let attempted = OSAllocatedUnfairLock<URL?>(initialState: nil)

    /// What the last attempt measured, `nil` when it ran to completion and has nothing to explain.
    var summary: String? {
        captured.withLock { $0 }
    }

    /// Where the request ended up, `nil` until failover moves it off the URL it started on.
    var attemptedURL: URL? {
        attempted.withLock { $0 }
    }

    func noteAttempt(_ url: URL) {
        attempted.withLock { $0 = url }
    }

    /// Metrics are not delivered for every task, so what the previous attempt measured is dropped
    /// before the next one starts instead of being reported against the attempt that outlived it.
    func beginAttempt() {
        captured.withLock { $0 = nil }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        let summary = Self.describe(metrics, budget: task.originalRequest?.timeoutInterval)
        captured.withLock { $0 = summary }
    }

    private static func describe(_ metrics: URLSessionTaskMetrics, budget: TimeInterval?) -> String? {
        guard let transaction = metrics.transactionMetrics.last, let phase = phase(transaction) else {
            return nil
        }

        let elapsed = seconds(metrics.taskInterval.duration)

        return [
            phase,
            budget.map { "\(elapsed) of \(seconds($0))" } ?? elapsed,
            transaction.isCellular ? "over cellular" : nil,
        ].compactMap { $0 }.joined(separator: " • ")
    }

    /// The stage still open when the transaction stopped: each date is stamped as its stage ends,
    /// so the first one missing is where it stalled. A cached response never reached the network
    /// and has nothing to report, and a reused connection reports no lookup or connect dates at
    /// all, hence the guards. TLS is checked before them, since `connectEndDate` is only stamped
    /// once the handshake is through.
    private static func phase(_ metrics: URLSessionTaskTransactionMetrics) -> String? {
        if metrics.resourceFetchType == .localCache { return nil }
        if metrics.domainLookupStartDate != nil, metrics.domainLookupEndDate == nil { return "resolving host" }
        if metrics.secureConnectionStartDate != nil, metrics.secureConnectionEndDate == nil { return "negotiating TLS" }
        if !metrics.isReusedConnection, metrics.connectEndDate == nil { return "connecting" }
        if metrics.requestEndDate == nil { return "sending request" }
        if metrics.responseStartDate == nil { return "waiting for response" }
        if metrics.responseEndDate == nil { return "receiving response" }

        return nil
    }

    private static func seconds(_ value: TimeInterval) -> String {
        value.formatted(.number.precision(.fractionLength(value < 10 ? 2 : 0))) + "s"
    }
}

#if DEBUG
extension FailedRequest {
    static var previews: [FailedRequest] {
        [
            FailedRequest(
                id: UUID(), date: Date(), method: "GET",
                url: "https://radarr.example.com/api/v3/movie",
                instance: "radarr-a1b2c3d4", reason: .status(code: 401, message: "Unauthorized")
            ),
            FailedRequest(
                id: UUID(), date: Date().addingTimeInterval(-42), method: "POST",
                url: "http://192.168.1.10:8989/api/v3/release",
                instance: "sonarr-e5f6a7b8", reason: .status(code: 500, message: "Internal Server Error")
            ),
            FailedRequest(
                id: UUID(), date: Date().addingTimeInterval(-190), method: "GET",
                url: "https://radarr.example.com/api/v3/system/status",
                instance: "radarr-a1b2c3d4", reason: .transport("The request timed out. (-1001)"),
                transport: "waiting for response • 2.51s of 2.50s"
            ),
            FailedRequest(
                id: UUID(), date: Date().addingTimeInterval(-360), method: "GET",
                url: "https://sonarr.example.com/api/v3/series",
                instance: "sonarr-e5f6a7b8", reason: .decoding("images.0.remoteUrl: Expected String but found null.")
            ),
        ]
    }
}
#endif
