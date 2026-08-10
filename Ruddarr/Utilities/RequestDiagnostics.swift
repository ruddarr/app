import Foundation

actor RequestDiagnostics {
    static let shared = RequestDiagnostics()

    private var entries: [FailedRequest] = []
    private let limit = 50

    func record(
        method: String,
        url: String,
        instance: String?,
        reason: FailedRequest.Reason,
        code: Int? = nil,
        trace: TransportTrace = .init()
    ) {
        let instance = (instance?.isEmpty == false) ? instance : nil

        // Matched on the reason alone, not the measurements: `trace` carries wall times that differ
        // on every attempt, so including it would turn one repeating failure into 50 near-duplicates.
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
                code: code,
                trace: trace
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

    /// The underlying `URLError`/`NSError` code. Kept beside the localized description because that
    /// text is rendered in the device's language — a report from a non-English device is otherwise
    /// impossible to search or triage on the error alone.
    var code: Int?

    /// What the transport measured, when the failure got far enough to measure anything.
    var trace: TransportTrace = .init()

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

    /// The numeric code rendered for display, e.g. ` (-1001)`. Appended by the diagnostics screen
    /// and export *after* masking, since a number never needs masking.
    var codeSuffix: String {
        code.map { " (\($0))" } ?? ""
    }
}

#if DEBUG
extension FailedRequest {
    static var previews: [FailedRequest] {
        [
            FailedRequest(
                id: UUID(), date: Date(), method: "GET",
                url: "https://radarr.example.com/api/v3/movie",
                instance: "Radarr", reason: .status(code: 401, message: "Unauthorized")
            ),
            FailedRequest(
                id: UUID(), date: Date().addingTimeInterval(-42), method: "POST",
                url: "http://192.168.1.10:8989/api/v3/release",
                instance: "Sonarr", reason: .status(code: 500, message: "Internal Server Error")
            ),
            FailedRequest(
                id: UUID(), date: Date().addingTimeInterval(-190), method: "GET",
                url: "https://radarr.example.com/api/v3/system/status",
                instance: "Radarr", reason: .transport("The request timed out."),
                code: URLError.timedOut.rawValue,
                trace: TransportTrace(budget: 2.5, elapsed: 2.51, phase: .waiting, cellular: false)
            ),
            FailedRequest(
                id: UUID(), date: Date().addingTimeInterval(-360), method: "GET",
                url: "https://sonarr.example.com/api/v3/series",
                instance: "Sonarr", reason: .decoding("images.0.remoteUrl: Expected String but found null.")
            ),
        ]
    }
}
#endif
