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
    formatter.isAdaptive = adaptive // bytes < 1_000_000_000

    return formatter.string(fromByteCount: Int64(bytes))
}

func formatBytes(_ bytes: Float) -> String {
    guard bytes.isFinite, bytes > 0 else {
        return formatBytes(0)
    }

    guard bytes < Float(Int.max) else {
        return formatBytes(.max)
    }

    return formatBytes(Int(bytes))
}

func formatBitrate(_ bitrate: Int) -> String? {
    if bitrate == 0 {
        return nil
    }

    if bitrate < 1_000_000 {
        return "%d kbps".placeholders(bitrate / 1_000)
    }

    let mbps = Double(bitrate) / 1_000_000.0

    return "%@ mbps".placeholders(mbps.formatted(.decimal(mbps < 10 ? 1 : 0)))
}

func formatAge(_ ageInMinutes: Float) -> String {
    let minutes: Int = Int(ageInMinutes)
    let days: Int = minutes / 60 / 24
    let years: Float = Float(days) / 30 / 12

    return switch minutes {
    case -10_000..<1: // less than 1 minute (or bad data from radarr)
        String(localized: "Just now")
    case 1..<119: // less than 120 minutes
        String(localized: "%d minutes").placeholders(minutes)
    case 120..<2_880: // less than 48 hours
        String(localized: "%d hours").placeholders(minutes / 60)
    case 2_880..<129_600: // less than 90 days
        String(localized: "%d days").placeholders(days)
    case 129_600..<525_600: // less than 365 days
        String(localized: "%d months").placeholders(days / 30)
    case 525_600..<2_628_000: // less than 5 years
        String(localized: "%@ years").placeholders(years.formatted(.decimal(1)))
    default:
        String(localized: "%@ years").placeholders(Int(years))
    }
}

extension FormatStyle {
    static func decimal<Value>(_ fractionLength: Int) -> DecimalFormatStyle<Value>
        where Self == DecimalFormatStyle<Value> {
        DecimalFormatStyle(fractionLength: fractionLength)
    }
}

extension FormatStyle where Self == PercentageRating {
    static var percentageRating: PercentageRating { .init() }
}

struct PercentageRating: FormatStyle {
    func format(_ value: Float) -> String {
        value.formatted(.decimal(0)) + "%"
    }
}

struct DecimalFormatStyle<Value: BinaryFloatingPoint>: FormatStyle {
    let fractionLength: Int

    func format(_ value: Value) -> String {
        value.formatted(
            FloatingPointFormatStyle<Value>()
                .precision(.fractionLength(fractionLength))
                .grouping(.never)
        )
    }
}
