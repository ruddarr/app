import Foundation

actor RequestDiagnostics {
    static let shared = RequestDiagnostics()

    private var entries: [FailedRequest] = []
    private let limit = 50

    func record(method: String, url: String, instance: String?, reason: FailedRequest.Reason) {
        let instance = (instance?.isEmpty == false) ? instance : nil

        if let last = entries.first,
           last.method == method, last.url == url, last.instance == instance, last.reason == reason {
            return
        }

        entries.insert(
            FailedRequest(
                id: UUID(),
                date: Date(),
                method: method,
                url: url,
                instance: instance,
                reason: reason
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

    func seed(_ entries: [FailedRequest]) {
        self.entries = entries
    }
}

struct FailedRequest: Identifiable, Equatable, Sendable {
    let id: UUID
    let date: Date
    let method: String
    let url: String
    let instance: String?
    let reason: Reason

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

extension FailedRequest.Reason {
    init(_ error: API.Error) { // swiftlint:disable:this cyclomatic_complexity

        switch error {
        case .badStatusCode(let code):
            self = .status(code: code, message: nil)
        case .errorResponse(let code, let message):
            self = .status(code: code, message: message)
        case .decodingError(let error):
            let path = error.context.codingPath.map(\.stringValue).joined(separator: ".")
            let description = error.context.debugDescription
            self = .decoding(path.isEmpty ? description : "\(path): \(description)")
        case .notConnectedToInternet:
            self = .transport("Not connected to the internet")
        case .timeoutOnPrivateIp(let error):
            self = .transport(error.localizedDescription)
        case .urlError(let error):
            self = .transport(error.localizedDescription)
        case .nsError(let error):
            self = .transport(error.localizedDescription)
        case .localizedError(let error):
            self = .transport(error.errorDescription ?? String(describing: error))
        case .appError(let error):
            self = .transport(error.errorDescription ?? String(describing: error))
        case .invalidUrl(let url):
            self = .transport("Invalid URL: \(url)")
        case .error(let error):
            self = .transport(String(describing: error))
        case .void:
            self = .transport("Request failed")
        }
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
                instance: "Radarr", reason: .transport("The request timed out.")
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
