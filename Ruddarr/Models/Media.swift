import SwiftUI

struct MediaLanguage: Codable {
    let id: Int
    let name: String?

    var label: String {
        name ?? String(localized: "Unknown")
    }
}

struct MediaCustomFormat: Identifiable, Codable {
    let id: Int
    let name: String?

    var label: String {
        name ?? String(localized: "Unknown")
    }
}

enum MediaReleaseType: String, Codable {
    case usenet
    case torrent
    case unknown

    var label: String {
        switch self {
        case .usenet: String(localized: "Usenet")
        case .torrent: String(localized: "Torrent")
        case .unknown: String(localized: "Unknown")
        }
    }
}

struct MediaQuality: Codable {
    let quality: MediaQualityDetails
    let revision: MediaQualityRevision
}

struct MediaQualityDetails: Codable {
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
            return String(name![range].dropFirst())
        }

        return label
            .replacingOccurrences(of: "BR-DISK", with: "1080p")
            .replacingOccurrences(of: "Raw-HD", with: "1080p")
            .replacingOccurrences(of: "DVD-R", with: "480p")
            .replacingOccurrences(of: "SDTV", with: "480p")
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

struct MediaQualityRevision: Codable {
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
    case tv // swiftlint:disable:this identifier_name
    case television
    case televisionRaw
    case web
    case webdl
    case webrip
    case webRip
    case bluray
    case blurayRaw

    // TODO: currently only used by movie detail view
    var label: String {
        switch self {
        case .unknown: String(localized: "Unknown")
        case .cam: "CAM"
        case .telesync: "TELESYNC"
        case .telecine: "TELECINE"
        case .workprint: "WORKPRINT"
        case .dvd: "DVD"
        case .tv: "TV"
        case .television: "television..."
        case .televisionRaw: "Raw-HD"
        case .web: "WEB..."
        case .webdl: "WEBDL"
        case .webrip, .webRip: "WEBRip"
        case .bluray: "Bluray"
        case .blurayRaw: "Bluray Remux ..."
        }
    }
}

func languageSingleLabel(_ languages: [MediaLanguage]) -> String {
    if languages.isEmpty {
        return String(localized: "Unknown")
    }

    if languages.count == 1 {
        return languages[0].label

    }

    return String(localized: "Multilingual")
}

struct MediaPreviewActionModifier: ViewModifier {
    func body(content: Content) -> some View {
        if UIDevice.current.userInterfaceIdiom == .phone {
            content.frame(maxWidth: .infinity)
        } else {
            content.frame(maxWidth: 215)
        }
    }
}

struct MediaPreviewActionSpacerModifier: ViewModifier {
    func body(content: Content) -> some View {
        if UIDevice.current.userInterfaceIdiom == .phone {
            content.frame(maxWidth: .infinity)
        } else {
            content
        }
    }
}

struct MediaDetailsPosterModifier: ViewModifier {
    func body(content: Content) -> some View {
        if UIDevice.current.userInterfaceIdiom == .phone {
            content.containerRelativeFrame(.horizontal, count: 5, span: 2, spacing: 0)
        } else {
            content.frame(width: 200, height: 300)
        }
    }
}
