import Foundation

// swiftlint:disable:next cyclomatic_complexity
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

func formatRuntime(_ minutes: Int) -> String? {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.hour, .minute]
    formatter.unitsStyle = .abbreviated

    return formatter.string(from: TimeInterval(minutes * 60))
        ?? formatter.string(from: 0)
}

func formatTags(_ ids: [Int], tags: [Tag]) -> String {
    guard !ids.isEmpty else {
        return String(localized: "None")
    }

    return ids.map { id in
        tags.first { $0.id == id }?.label ?? String(id)
    }.joined(separator: ", ")
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
