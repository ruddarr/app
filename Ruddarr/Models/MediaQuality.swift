import Foundation

struct MediaQuality: Equatable, Codable {
    let quality: MediaQualityDetails
    let revision: MediaQualityRevision
}

struct MediaQualityDetails: Equatable, Codable {
    let name: String?
    let source: MediaQualitySource
    let resolution: Int
    let modifier: MediaReleaseQualityModifier?

    var label: String {
        name ?? String(localized: "Unknown")
    }

    var normalizedName: String {
        guard let label = name else {
            return String(localized: "Unknown")
        }

        if let range = label.range(of: #"-(\d+p)"#, options: .regularExpression) {
            return String(label[range].dropFirst())
        }

        return label
            .replacingOccurrences(of: "BR-DISK", with: "1080p")
            .replacingOccurrences(of: "Raw-HD", with: "1080p")
            .replacingOccurrences(of: "DVD-R", with: "480p")
            .replacingOccurrences(of: "SDTV", with: "480p")
    }

    var sourceLabel: String {
        switch source {
        case .unknown: String(localized: "Unknown")
        case .cam: "CAM"
        case .telesync: "TELESYNC"
        case .telecine: "TELECINE"
        case .workprint: "WORKPRINT"
        case .dvd: "DVD"
        case .tv: "TV"
        case .television: resolution < 480 ? "SDTV" : "HDTV"
        case .televisionRaw: "Raw-HD"
        case .web, .webdl: "WEBDL"
        case .webrip, .webRip: "WEBRip"
        case .bluray: "Bluray"
        case .blurayRaw: "Remux"
        }
    }
}

enum MediaReleaseQualityModifier: String, Codable {
    case none
    case regional
    case screener
    case rawhd
    case brdisk
    case remux
}

struct MediaQualityRevision: Equatable, Codable {
    let version: Int
    let real: Int
    let isRepack: Bool

    var isReal: Bool {
        real > 0
    }

    var isProper: Bool {
        version > 1
    }
}

enum MediaQualitySource: String, Codable {
    case unknown
    case cam
    case telesync
    case telecine
    case workprint
    case dvd
    case tv
    case television
    case televisionRaw
    case web
    case webdl
    case webrip
    case webRip
    case bluray
    case blurayRaw
}
