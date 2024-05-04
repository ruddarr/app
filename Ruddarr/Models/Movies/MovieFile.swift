import Foundation

struct MovieFile: Identifiable, Codable {
    let id: Int
    let size: Int
    let relativePath: String?
    let dateAdded: Date

    let mediaInfo: MovieMediaInfo?
    let quality: MovieQualityInfo
    let languages: [MediaLanguage]
    let customFormats: [MovieCustomFormat]?
    let customFormatScore: Int?

    var sizeLabel: String {
        ByteCountFormatter.string(
            fromByteCount: Int64(size),
            countStyle: .binary
        )
    }

    var languageLabel: String {
        languageSingleLabel(languages)
    }

    var scoreLabel: String {
        formatCustomScore(customFormatScore ?? 0)
    }

    var customFormatsList: [String]? {
        guard let formats = customFormats else {
            return nil
        }

        return formats.map { $0.label }
    }

    var videoResolution: Int? {
        if quality.quality.resolution > 0 {
            return quality.quality.resolution
        }

        if let resolution = mediaInfo?.resolution, let range = resolution.range(of: "x") {
            return Int(resolution[range.upperBound...])
        }

        return nil
    }
}

struct MovieMediaInfo: Codable {
    let audioBitrate: Int
    let audioStreamCount: Int
    let audioChannels: Float
    let audioCodec: String?
    let audioLanguages: String?

    let videoBitDepth: Int
    let videoBitrate: Int
    let videoFps: Float
    let videoCodec: String?
    let resolution: String?
    let runTime: String?
    let videoDynamicRange: String?
    let videoDynamicRangeType: String?
    let scanType: String?

    let subtitles: String?

    var videoCodecLabel: String? {
        guard var label = videoCodec else {
            return nil
        }

        label = label.replacingOccurrences(of: "x264", with: "H264")
        label = label.replacingOccurrences(of: "h264", with: "H264")
        label = label.replacingOccurrences(of: "h265", with: "HEVC")
        label = label.replacingOccurrences(of: "x265", with: "HEVC")

        return label
    }

    var videoDynamicRangeLabel: String? {
        guard let label = videoDynamicRange, !label.isEmpty else {
            return nil
        }

        if let type = videoDynamicRangeType {
            if type == "HDR10" { return "HDR10" }
            if type == "HDR10Plus" { return "HDR10+" }
            if !type.isEmpty { return "\(label) (\(type))" }
        }

        return label
    }

    var audioLanguageCodes: [String]? {
        guard let languages = audioLanguages, languages.count > 0 else {
            return nil
        }

        let codes = Array(Set(
            languages.components(separatedBy: "/")
        ))

        return codes.sorted(by: Languages.codeSort)
    }

    var subtitleCodes: [String]? {
        guard let languages = subtitles, languages.count > 0 else {
            return nil
        }

        let codes = Array(Set(
            languages.components(separatedBy: "/")
        ))

        return codes.sorted(by: Languages.codeSort)
    }
}

struct MovieQualityInfo: Codable {
    let quality: MovieQuality
}

struct MovieQuality: Codable {
    let name: String?
    let resolution: Int

    var label: String {
        name ?? String(localized: "Unknown")
    }
}

struct MovieCustomFormat: Identifiable, Codable {
    let id: Int
    let name: String?

    var label: String {
        name ?? String(localized: "Unknown")
    }
}
