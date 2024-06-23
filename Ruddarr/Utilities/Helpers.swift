import Foundation
import SwiftUI

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
}

func formatRuntime(_ minutes: Int) -> String {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.hour, .minute]
    formatter.unitsStyle = .abbreviated

    return formatter.string(from: TimeInterval(minutes * 60)) ?? formatter.string(from: 0)!
}

func formatRemainingTime(_ date: Date) -> String? {
    let seconds = date.timeIntervalSince(Date.now)
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .abbreviated
    formatter.includesTimeRemainingPhrase = true
    formatter.allowedUnits = seconds >= 3_600 ? [.hour, .minute] : [.minute, .second]
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
    case "FileList": "FL"
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

func formatAge(_ age: Float) -> String {
    let minutes: Int = Int(age)
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

extension View {
    func tag() -> some View {
        self.modifier(ListItemHelper.Tag())
    }
}

struct ListItemHelper {
    static let posterRadius = 10.0
    
    static func primaryTextStyle() -> Font {
        #if os(macOS)
            return .title2
        #else
            return .body
        #endif
    }
    
    static func secondaryTextStyle() -> Font {
        #if os(macOS)
            return .body
        #else
            return .footnote
        #endif
    }
    
    static func tertiaryTextStyle() -> Font {
        #if os(macOS)
            return .body
        #else
            return .caption
        #endif
    }
    
    static func listItemSpacing() -> CGFloat {
        #if os(macOS)
            return 20
        #else
            if UIDevice.current.userInterfaceIdiom == .phone {
                return 12
            }
            return 20
        #endif
    }
    
    static func posterHeight() -> CGFloat {
        #if os(macOS)
            return 176.0
        #else
            return 140.0
        #endif
    }
    
    struct Tag: ViewModifier {
        func body(content: Content) -> some View {
            content.lineLimit(1).opacity(0.8).padding(.horizontal, 6).padding(.vertical, 2).background(.foreground.opacity(0.15)).clipShape(RoundedRectangle(cornerRadius: 4))
        }
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
}
