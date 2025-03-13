import Foundation
import CloudKit

protocol OptionalProtocol {
    associatedtype Wrapped
    var wrappedValue: Wrapped? { get set }
}

extension Optional: OptionalProtocol {
    var wrappedValue: Wrapped? {
        get { self }
        set { self = newValue }
    }
}

extension String {
    var untrailingSlashIt: String? {
        var string = self

        while string.hasSuffix("/") {
            string = String(string.dropLast())
        }

        return string
    }

    func toMarkdown() -> AttributedString {
        do {
            return try AttributedString(markdown: self)
        } catch {
            print("Error parsing Markdown for string \(self): \(error)")

            return AttributedString(self)
        }
    }

    func trimmed() -> String {
        self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension UUID {
    func isEqual(to string: String) -> Bool {
        self.uuidString.caseInsensitiveCompare(string) == .orderedSame
    }

    var shortened: String {
        self.uuidString.prefix(8).lowercased()
    }
}

extension Hashable {
    func equals(_ other: any Hashable) -> Bool {
        if type(of: self) != type(of: other) {
            return false
        }

        if let other = other as? Self {
            return self == other
        }

        return false
    }
}

func inferredInstallDate() -> Date? {
    guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last else {
        return nil
    }

    guard let attributes = try? FileManager.default.attributesOfItem(atPath: documentsURL.path) else {
        return nil
    }

    return attributes[.creationDate] as? Date
}

func formatRuntime(_ minutes: Int) -> String? {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.hour, .minute]
    formatter.unitsStyle = .abbreviated

    return formatter.string(from: TimeInterval(minutes * 60))
        ?? formatter.string(from: 0)
}

func formatRemainingTime(_ date: Date) -> String? {
    let seconds = date.timeIntervalSince(Date.now)
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .abbreviated
    formatter.includesTimeRemainingPhrase = true
    formatter.allowedUnits = seconds >= 3_600 ? [.hour] : [.minute, .second]
    return formatter.string(from: seconds)
}

func formatBytes(_ bytes: Int, adaptive: Bool = false) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .binary

    if adaptive {
        formatter.isAdaptive = bytes < 1_073_741_824 // 1 GB
    }

    return formatter.string(fromByteCount: Int64(bytes))
}

func formatBitrate(_ bitrate: Int) -> String? {
    if bitrate == 0 {
        return nil
    }

    if bitrate < 1_000_000 {
        return String(format: "%d kbps", bitrate / 1_000)
    }

    let mbps = Double(bitrate) / 1_000_000.0

    return String(format: "%.\(mbps < 10 ? 1 : 0)f mbps", mbps)
}

func calculateBitrate(_ seconds: Int, _ bytes: Int) -> Int? {
    guard seconds > 0 else { return nil }
    return (bytes * 8) / seconds
}

func calculateRuntime(_ runtime: String?) -> Int? {
    guard let runtime, !runtime.isEmpty else { return nil }

    return runtime.split(separator: ":")
        .compactMap { Int($0) }
        .reduce(0) { $0 * 60 + $1 }
}

// swiftlint:disable cyclomatic_complexity
func formatIndexer(_ name: String) -> String {
    var indexer = name

    if indexer.hasSuffix(" (Prowlarr)") {
        indexer = String(indexer.dropLast(11))
    }

    if indexer.hasSuffix(" (API)") {
        indexer = String(indexer.dropLast(6))
    }

    return switch indexer {
    case "BeyondHD": "BHD"
    case "Blutopia": "BLU"
    case "BroadcasTheNet": "BTN"
    case "FileList": "FL"
    case "HDBits": "HDB"
    case "IPTorrents": "IPT"
    case "MyAnonaMouse": "MAM"
    case "PassThePopcorn": "PTP"
    case "REDacted": "RED"
    case "TorrentDay": "TD"
    case "TorrentLeech": "TL"
    case "DrunkenSlug": "DS"
    default: indexer
    }
}
// swiftlint:enable cyclomatic_complexity

func extractImdbId(_ text: String) -> String? {
    let pattern = /imdb\.com\/title\/(tt\d+)/

    if let matches = try? pattern.firstMatch(in: text) {
        return String(matches.1)
    }

    return nil
}

func formatAge(_ ageInMinutes: Float) -> String {
    let minutes: Int = Int(ageInMinutes)
    let days: Int = minutes / 60 / 24
    let years: Float = Float(days) / 30 / 12

    return switch minutes {
    case -10_000..<1: // less than 1 minute (or bad data from radarr)
        String(localized: "Just now")
    case 1..<119: // less than 120 minutes
        String(format: String(localized: "%d minutes"), minutes)
    case 120..<2_880: // less than 48 hours
        String(format: String(localized: "%d hours"), minutes / 60)
    case 2_880..<129_600: // less than 90 days
        String(format: String(localized: "%d days"), days)
    case 129_600..<525_600: // less than 365 days
        String(format: String(localized: "%d months"), days / 30)
    case 525_600..<2_628_000: // less than 5 years
        String(format: String(localized: "%.1f years"), years)
    default:
        String(format: String(localized: "%d years"), Int(years))
    }
}

func cloudKitStatusString(_ status: CKAccountStatus?) -> String {
    switch status {
    case .couldNotDetermine: "could-not-determine"
    case .available: "available"
    case .restricted: "restricted"
    case .noAccount: "no-account"
    case .temporarilyUnavailable: "temporarily-unavailable"
    case .none: "nil"
    @unknown default: "unknown"
    }
}

class PreviewData {
    static func load<T: Codable> (name: String) -> [T] {
        if let path = Bundle.main.path(forResource: name, ofType: "json") {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path))

                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601extended

                return try decoder.decode([T].self, from: data)
            } catch {
                print("Could not load preview data: \(error)")
                fatalError("Could not load preview data: \(error)")
            }
        }

        print("Invalid preview data path: \(name)")
        fatalError("Invalid preview data path: \(name)")
    }

    static func loadObject<T: Codable> (name: String) -> T {
        if let path = Bundle.main.path(forResource: name, ofType: "json") {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path))

                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601extended

                return try decoder.decode(T.self, from: data)
            } catch {
                print("Could not load preview data: \(error)")
                fatalError("Could not load preview data: \(error)")
            }
        }

        print("Invalid preview data path: \(name)")
        fatalError("Invalid preview data path: \(name)")
    }
}
